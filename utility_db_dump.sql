--
-- PostgreSQL database dump
--

\restrict NHwLar05hw2VgFNdvbR4WuBOqwGYMTEBkwNNCIAD7kbqHzy3ghK4OXzXwczV2yU

-- Dumped from database version 18.4
-- Dumped by pg_dump version 18.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: generate_bill_notification(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.generate_bill_notification() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_customer_name VARCHAR(255);
    v_month_year VARCHAR(20);
    v_amount VARCHAR(50);
BEGIN
    SELECT c.full_names INTO v_customer_name
    FROM customers c WHERE c.id = NEW.customer_id;

    v_month_year := TO_CHAR(TO_DATE(NEW.billing_month::text || ' ' || NEW.billing_year::text, 'MM YYYY'), 'Month YYYY');
    v_amount := NEW.total_amount::text;

    INSERT INTO notifications (customer_id, bill_id, message, notification_type)
    VALUES (
        NEW.customer_id,
        NEW.id,
        'Dear ' || v_customer_name || ', Your ' || v_month_year || ' utility bill of ' || v_amount || ' FRW has been successfully processed.',
        'BILL_GENERATED'
    );

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.generate_bill_notification() OWNER TO postgres;

--
-- Name: on_payment_update_bill(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.on_payment_update_bill() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_bill RECORD;
    v_total_paid DECIMAL(15,2);
    v_customer_name VARCHAR(255);
    v_month_year VARCHAR(20);
    v_amount VARCHAR(50);
BEGIN
    SELECT * INTO v_bill FROM bills WHERE id = NEW.bill_id;

    SELECT COALESCE(SUM(amount_paid), 0) INTO v_total_paid
    FROM payments WHERE bill_id = NEW.bill_id;

    IF v_total_paid >= v_bill.total_amount THEN
        UPDATE bills
        SET outstanding_balance = 0,
            bill_status = 'PAID',
            updated_at = NOW()
        WHERE id = NEW.bill_id;

        SELECT c.full_names INTO v_customer_name
        FROM customers c WHERE c.id = v_bill.customer_id;

        v_month_year := TO_CHAR(TO_DATE(v_bill.billing_month::text || ' ' || v_bill.billing_year::text, 'MM YYYY'), 'Month YYYY');
        v_amount := v_bill.total_amount::text;

        INSERT INTO notifications (customer_id, bill_id, message, notification_type)
        VALUES (
            v_bill.customer_id,
            v_bill.id,
            'Dear ' || v_customer_name || ', Your ' || v_month_year || ' utility bill of ' || v_amount || ' FRW has been successfully processed.',
            'PAYMENT_COMPLETED'
        );
    ELSE
        UPDATE bills
        SET outstanding_balance = v_bill.total_amount - v_total_paid,
            bill_status = 'PARTIALLY_PAID',
            updated_at = NOW()
        WHERE id = NEW.bill_id;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.on_payment_update_bill() OWNER TO postgres;

--
-- Name: sp_generate_bill(bigint, date, bigint); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_generate_bill(IN p_meter_reading_id bigint, IN p_due_date date, IN p_approved_by bigint)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_reading RECORD;
    v_meter RECORD;
    v_customer RECORD;
    v_consumption DECIMAL(15,2);
    v_tariff_charge DECIMAL(15,2) := 0;
    v_fixed_charge DECIMAL(15,2) := 0;
    v_tax_amount DECIMAL(15,2) := 0;
    v_penalty_amount DECIMAL(15,2) := 0;
    v_total DECIMAL(15,2);
    v_tariff_id BIGINT;
    v_rate DECIMAL(15,4);
    v_bill_number VARCHAR(100);
    v_tax_pct DECIMAL(5,2);
    v_penalty_pct DECIMAL(5,2);
    v_grace_days INT;
    v_existing_bill_count INT;
    v_tariff_type_val VARCHAR(20);
    v_remaining DECIMAL(15,2);
    v_tier_charge DECIMAL(15,2);
    v_tier_min DECIMAL(15,2);
    v_tier_max DECIMAL(15,2);
    v_tier_rate DECIMAL(15,4);
    v_tier_consumable DECIMAL(15,2);
BEGIN
    SELECT * INTO v_reading FROM meter_readings WHERE id = p_meter_reading_id;
    SELECT * INTO v_meter FROM meters WHERE id = v_reading.meter_id;
    SELECT * INTO v_customer FROM customers WHERE id = v_meter.customer_id;

    IF v_customer.status != 'ACTIVE' THEN
        RAISE EXCEPTION 'Customer is not active. Bills cannot be generated for inactive customers.';
    END IF;

    IF v_meter.status != 'ACTIVE' THEN
        RAISE EXCEPTION 'Meter is not active.';
    END IF;

    SELECT COUNT(*) INTO v_existing_bill_count FROM bills WHERE meter_reading_id = p_meter_reading_id;
    IF v_existing_bill_count > 0 THEN
        RAISE EXCEPTION 'Bill already exists for this meter reading.';
    END IF;

    v_consumption := v_reading.current_reading - v_reading.previous_reading;

    SELECT t.id INTO v_tariff_id
    FROM tariffs t
    WHERE t.meter_type = v_meter.meter_type
      AND t.is_active = TRUE
      AND t.effective_from <= CURRENT_DATE
      AND (t.effective_to IS NULL OR t.effective_to >= CURRENT_DATE)
    ORDER BY t.version DESC LIMIT 1;

    IF v_tariff_id IS NULL THEN
        RAISE EXCEPTION 'No active tariff found for meter type %', v_meter.meter_type;
    END IF;

    SELECT tariff_type INTO v_tariff_type_val FROM tariffs WHERE id = v_tariff_id;

    IF v_tariff_type_val = 'FLAT' THEN
        SELECT rate INTO v_rate FROM tariff_tiers WHERE tariff_id = v_tariff_id ORDER BY min_consumption LIMIT 1;
        v_tariff_charge := v_consumption * v_rate;
    ELSE
        v_remaining := v_consumption;
        v_tariff_charge := 0;

        FOR v_tier_min, v_tier_max, v_tier_rate IN
            SELECT min_consumption, max_consumption, rate
            FROM tariff_tiers
            WHERE tariff_id = v_tariff_id
            ORDER BY min_consumption
        LOOP
            IF v_remaining <= 0 THEN EXIT; END IF;

            v_tier_max := COALESCE(v_tier_max, v_consumption + v_tier_min);

            IF v_consumption > v_tier_min THEN
                v_tier_consumable := LEAST(v_remaining, v_tier_max - v_tier_min);
                v_tier_charge := v_tier_consumable * v_tier_rate;
                v_tariff_charge := v_tariff_charge + GREATEST(v_tier_charge, 0);
                v_remaining := v_remaining - v_tier_consumable;
            END IF;
        END LOOP;
    END IF;

    SELECT COALESCE(SUM(amount), 0) INTO v_fixed_charge
    FROM fixed_charges
    WHERE meter_type = v_meter.meter_type
      AND is_active = TRUE
      AND effective_from <= CURRENT_DATE
      AND (effective_to IS NULL OR effective_to >= CURRENT_DATE);

    SELECT COALESCE(SUM(percentage), 0) INTO v_tax_pct FROM taxes WHERE is_active = TRUE;
    v_tax_amount := (v_tariff_charge + v_fixed_charge) * (v_tax_pct / 100);

    SELECT COALESCE(SUM(percentage), 0), COALESCE(MAX(grace_period_days), 0) INTO v_penalty_pct, v_grace_days
    FROM penalties WHERE is_active = TRUE;

    IF EXISTS (
        SELECT 1 FROM bills
        WHERE customer_id = v_customer.id
          AND bill_status IN ('PENDING', 'PARTIALLY_PAID', 'OVERDUE')
          AND due_date < CURRENT_DATE
    ) THEN
        v_penalty_amount := (v_tariff_charge + v_fixed_charge) * (v_penalty_pct / 100);
    END IF;

    v_total := v_tariff_charge + v_fixed_charge + v_tax_amount + v_penalty_amount;

    v_bill_number := 'BILL-' || v_meter.meter_type || '-' || v_reading.reading_month || '-' || v_reading.reading_year || '-' || v_meter.meter_number;

    INSERT INTO bills (
        bill_number, customer_id, meter_id, meter_reading_id,
        billing_month, billing_year, consumption,
        tariff_charge, fixed_charge, tax_amount, penalty_amount,
        total_amount, outstanding_balance, bill_status, due_date,
        approved_by, approved_at
    ) VALUES (
        v_bill_number, v_customer.id, v_meter.id, v_reading.id,
        v_reading.reading_month, v_reading.reading_year, v_consumption,
        v_tariff_charge, v_fixed_charge, v_tax_amount, v_penalty_amount,
        v_total, v_total, 'PENDING', p_due_date,
        p_approved_by, NOW()
    );
END;
$$;


ALTER PROCEDURE public.sp_generate_bill(IN p_meter_reading_id bigint, IN p_due_date date, IN p_approved_by bigint) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: bills; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bills (
    id bigint NOT NULL,
    bill_number character varying(100) NOT NULL,
    customer_id bigint NOT NULL,
    meter_id bigint NOT NULL,
    meter_reading_id bigint NOT NULL,
    billing_month integer NOT NULL,
    billing_year integer NOT NULL,
    consumption numeric(15,2) NOT NULL,
    tariff_charge numeric(15,2) DEFAULT 0 NOT NULL,
    fixed_charge numeric(15,2) DEFAULT 0 NOT NULL,
    tax_amount numeric(15,2) DEFAULT 0 NOT NULL,
    penalty_amount numeric(15,2) DEFAULT 0 NOT NULL,
    total_amount numeric(15,2) NOT NULL,
    outstanding_balance numeric(15,2) NOT NULL,
    bill_status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    due_date date NOT NULL,
    approved_by bigint,
    approved_at timestamp without time zone,
    generated_at timestamp without time zone DEFAULT now(),
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.bills OWNER TO postgres;

--
-- Name: bills_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.bills_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.bills_id_seq OWNER TO postgres;

--
-- Name: bills_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.bills_id_seq OWNED BY public.bills.id;


--
-- Name: customers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.customers (
    id bigint NOT NULL,
    full_names character varying(255) NOT NULL,
    national_id character varying(50) NOT NULL,
    email character varying(255) NOT NULL,
    phone_number character varying(50) NOT NULL,
    address text NOT NULL,
    status character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    user_id bigint,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.customers OWNER TO postgres;

--
-- Name: customers_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.customers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.customers_id_seq OWNER TO postgres;

--
-- Name: customers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.customers_id_seq OWNED BY public.customers.id;


--
-- Name: fixed_charges; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fixed_charges (
    id bigint NOT NULL,
    meter_type character varying(20) NOT NULL,
    charge_name character varying(255) NOT NULL,
    amount numeric(15,2) NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    effective_from date NOT NULL,
    effective_to date,
    is_active boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT now(),
    CONSTRAINT fixed_charges_meter_type_check CHECK (((meter_type)::text = ANY ((ARRAY['WATER'::character varying, 'ELECTRICITY'::character varying])::text[])))
);


ALTER TABLE public.fixed_charges OWNER TO postgres;

--
-- Name: fixed_charges_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.fixed_charges_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.fixed_charges_id_seq OWNER TO postgres;

--
-- Name: fixed_charges_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.fixed_charges_id_seq OWNED BY public.fixed_charges.id;


--
-- Name: meter_readings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.meter_readings (
    id bigint NOT NULL,
    meter_id bigint NOT NULL,
    previous_reading numeric(15,2) NOT NULL,
    current_reading numeric(15,2) NOT NULL,
    reading_date date NOT NULL,
    reading_month integer NOT NULL,
    reading_year integer NOT NULL,
    captured_by bigint NOT NULL,
    created_at timestamp without time zone DEFAULT now(),
    CONSTRAINT chk_reading_positive CHECK ((current_reading > previous_reading)),
    CONSTRAINT meter_readings_reading_month_check CHECK (((reading_month >= 1) AND (reading_month <= 12)))
);


ALTER TABLE public.meter_readings OWNER TO postgres;

--
-- Name: meter_readings_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.meter_readings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.meter_readings_id_seq OWNER TO postgres;

--
-- Name: meter_readings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.meter_readings_id_seq OWNED BY public.meter_readings.id;


--
-- Name: meters; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.meters (
    id bigint NOT NULL,
    meter_number character varying(100) NOT NULL,
    meter_type character varying(20) NOT NULL,
    installation_date date NOT NULL,
    status character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    customer_id bigint NOT NULL,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    CONSTRAINT meters_meter_type_check CHECK (((meter_type)::text = ANY ((ARRAY['WATER'::character varying, 'ELECTRICITY'::character varying])::text[])))
);


ALTER TABLE public.meters OWNER TO postgres;

--
-- Name: meters_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.meters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.meters_id_seq OWNER TO postgres;

--
-- Name: meters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.meters_id_seq OWNED BY public.meters.id;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.notifications (
    id bigint NOT NULL,
    customer_id bigint NOT NULL,
    bill_id bigint,
    message text NOT NULL,
    notification_type character varying(50) NOT NULL,
    is_read boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.notifications OWNER TO postgres;

--
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.notifications_id_seq OWNER TO postgres;

--
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.notifications_id_seq OWNED BY public.notifications.id;


--
-- Name: payments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.payments (
    id bigint NOT NULL,
    bill_id bigint NOT NULL,
    amount_paid numeric(15,2) NOT NULL,
    payment_method character varying(50) NOT NULL,
    payment_date timestamp without time zone DEFAULT now() NOT NULL,
    reference_number character varying(255),
    processed_by bigint,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.payments OWNER TO postgres;

--
-- Name: payments_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.payments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.payments_id_seq OWNER TO postgres;

--
-- Name: payments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.payments_id_seq OWNED BY public.payments.id;


--
-- Name: penalties; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.penalties (
    id bigint NOT NULL,
    penalty_name character varying(255) NOT NULL,
    penalty_type character varying(50) NOT NULL,
    percentage numeric(5,2) NOT NULL,
    grace_period_days integer DEFAULT 30 NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.penalties OWNER TO postgres;

--
-- Name: penalties_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.penalties_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.penalties_id_seq OWNER TO postgres;

--
-- Name: penalties_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.penalties_id_seq OWNED BY public.penalties.id;


--
-- Name: roles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.roles (
    id bigint NOT NULL,
    name character varying(50) NOT NULL
);


ALTER TABLE public.roles OWNER TO postgres;

--
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.roles_id_seq OWNER TO postgres;

--
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.roles_id_seq OWNED BY public.roles.id;


--
-- Name: tariff_tiers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tariff_tiers (
    id bigint NOT NULL,
    tariff_id bigint NOT NULL,
    min_consumption numeric(15,2) DEFAULT 0 NOT NULL,
    max_consumption numeric(15,2),
    rate numeric(15,4) NOT NULL,
    description character varying(255)
);


ALTER TABLE public.tariff_tiers OWNER TO postgres;

--
-- Name: tariff_tiers_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tariff_tiers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.tariff_tiers_id_seq OWNER TO postgres;

--
-- Name: tariff_tiers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tariff_tiers_id_seq OWNED BY public.tariff_tiers.id;


--
-- Name: tariffs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tariffs (
    id bigint NOT NULL,
    meter_type character varying(20) NOT NULL,
    tariff_type character varying(20) NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    effective_from date NOT NULL,
    effective_to date,
    is_active boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT now(),
    CONSTRAINT tariffs_meter_type_check CHECK (((meter_type)::text = ANY ((ARRAY['WATER'::character varying, 'ELECTRICITY'::character varying])::text[]))),
    CONSTRAINT tariffs_tariff_type_check CHECK (((tariff_type)::text = ANY ((ARRAY['FLAT'::character varying, 'TIERED'::character varying])::text[])))
);


ALTER TABLE public.tariffs OWNER TO postgres;

--
-- Name: tariffs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tariffs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.tariffs_id_seq OWNER TO postgres;

--
-- Name: tariffs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tariffs_id_seq OWNED BY public.tariffs.id;


--
-- Name: taxes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.taxes (
    id bigint NOT NULL,
    tax_name character varying(255) NOT NULL,
    tax_type character varying(50) NOT NULL,
    percentage numeric(5,2) NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.taxes OWNER TO postgres;

--
-- Name: taxes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.taxes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.taxes_id_seq OWNER TO postgres;

--
-- Name: taxes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.taxes_id_seq OWNED BY public.taxes.id;


--
-- Name: user_roles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_roles (
    user_id bigint NOT NULL,
    role_id bigint NOT NULL
);


ALTER TABLE public.user_roles OWNER TO postgres;

--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    full_names character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    phone_number character varying(50),
    password character varying(255) NOT NULL,
    status character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_id_seq OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: bills id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills ALTER COLUMN id SET DEFAULT nextval('public.bills_id_seq'::regclass);


--
-- Name: customers id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customers ALTER COLUMN id SET DEFAULT nextval('public.customers_id_seq'::regclass);


--
-- Name: fixed_charges id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fixed_charges ALTER COLUMN id SET DEFAULT nextval('public.fixed_charges_id_seq'::regclass);


--
-- Name: meter_readings id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.meter_readings ALTER COLUMN id SET DEFAULT nextval('public.meter_readings_id_seq'::regclass);


--
-- Name: meters id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.meters ALTER COLUMN id SET DEFAULT nextval('public.meters_id_seq'::regclass);


--
-- Name: notifications id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications ALTER COLUMN id SET DEFAULT nextval('public.notifications_id_seq'::regclass);


--
-- Name: payments id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments ALTER COLUMN id SET DEFAULT nextval('public.payments_id_seq'::regclass);


--
-- Name: penalties id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.penalties ALTER COLUMN id SET DEFAULT nextval('public.penalties_id_seq'::regclass);


--
-- Name: roles id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles ALTER COLUMN id SET DEFAULT nextval('public.roles_id_seq'::regclass);


--
-- Name: tariff_tiers id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tariff_tiers ALTER COLUMN id SET DEFAULT nextval('public.tariff_tiers_id_seq'::regclass);


--
-- Name: tariffs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tariffs ALTER COLUMN id SET DEFAULT nextval('public.tariffs_id_seq'::regclass);


--
-- Name: taxes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.taxes ALTER COLUMN id SET DEFAULT nextval('public.taxes_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Data for Name: bills; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bills (id, bill_number, customer_id, meter_id, meter_reading_id, billing_month, billing_year, consumption, tariff_charge, fixed_charge, tax_amount, penalty_amount, total_amount, outstanding_balance, bill_status, due_date, approved_by, approved_at, generated_at, created_at, updated_at) FROM stdin;
1	BILL-WATER-6-2026-MTR-WATER-1001	1	1	1	6	2026	120.00	42000.00	1500.00	7830.00	0.00	51330.00	0.00	PAID	2026-06-30	3	2026-06-05 12:13:06.103229	\N	2026-06-05 12:12:11.596049	2026-06-05 12:13:57.922252
2	BILL-WATER-6-2026-MTR-WATER-1002	1	2	2	6	2026	12.00	24.00	31500.00	6304.80	0.00	37828.80	2828.80	PARTIALLY_PAID	2026-07-02	1	2026-06-05 13:34:56.135565	\N	2026-06-05 13:32:27.606228	2026-06-05 13:37:37.214261
\.


--
-- Data for Name: customers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.customers (id, full_names, national_id, email, phone_number, address, status, user_id, created_at, updated_at) FROM stdin;
1	John Doe	1199580012345678	john.doe@example.com	+250780000001	Kigali, Rwanda	ACTIVE	\N	2026-06-05 11:56:59.359002	2026-06-05 11:56:59.359002
2	AGAHIRE Nikita	6737636367387638	agahirenikita@gmail.com	0787524574	Muhanga	ACTIVE	4	2026-06-05 12:41:01.805731	2026-06-05 12:42:46.045645
4	IRAMBONA Eric	0987655434325467	eric@gmail.com	0780904355	Kabuga	ACTIVE	\N	2026-06-05 14:19:12.766658	2026-06-05 14:19:12.766658
3	KAMANA Jaques	6465784876	jacques12@gmail.com	0785908706	Huye-Butare	ACTIVE	5	2026-06-05 14:08:38.684525	2026-06-05 14:21:13.544593
\.


--
-- Data for Name: fixed_charges; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.fixed_charges (id, meter_type, charge_name, amount, version, effective_from, effective_to, is_active, created_at) FROM stdin;
1	WATER	Water Service Infrastructure Fee	1500.00	1	2026-01-01	\N	t	2026-06-05 12:01:20.141689
2	WATER	Meter reading fee	30000.00	2	2026-06-05	2026-06-20	t	2026-06-05 13:11:36.352863
\.


--
-- Data for Name: meter_readings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.meter_readings (id, meter_id, previous_reading, current_reading, reading_date, reading_month, reading_year, captured_by, created_at) FROM stdin;
1	1	100.00	220.00	2026-06-05	6	2026	2	2026-06-05 12:06:46.193467
2	2	72.00	84.00	2026-06-07	6	2026	2	2026-06-05 12:49:38.643865
\.


--
-- Data for Name: meters; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.meters (id, meter_number, meter_type, installation_date, status, customer_id, created_at, updated_at) FROM stdin;
1	MTR-WATER-1001	WATER	2026-01-01	ACTIVE	1	2026-06-05 11:59:25.732207	2026-06-05 11:59:25.732207
2	MTR-WATER-1002	WATER	2026-06-30	ACTIVE	1	2026-06-05 12:34:55.394172	2026-06-05 12:48:28.137263
\.


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.notifications (id, customer_id, bill_id, message, notification_type, is_read, created_at) FROM stdin;
1	1	1	Dear John Doe, Your June      2026 utility bill of 51330.00 FRW has been successfully processed.	BILL_GENERATED	f	2026-06-05 12:12:11.493347
2	1	1	Dear John Doe, Your June      2026 utility bill of 51330.00 FRW has been successfully processed.	PAYMENT_COMPLETED	t	2026-06-05 12:13:57.847486
3	1	2	Dear John Doe, Your June      2026 utility bill of 37828.80 FRW has been successfully processed.	BILL_GENERATED	f	2026-06-05 13:32:27.567207
\.


--
-- Data for Name: payments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.payments (id, bill_id, amount_paid, payment_method, payment_date, reference_number, processed_by, created_at) FROM stdin;
1	1	51330.00	MOBILE_MONEY	2026-06-05 12:13:57.853487	TXN987654321	3	2026-06-05 12:13:57.854454
2	2	35000.00	MOBILE_MONEY	2026-06-05 13:37:37.184264	86309683966	1	2026-06-05 13:37:37.186261
\.


--
-- Data for Name: penalties; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.penalties (id, penalty_name, penalty_type, percentage, grace_period_days, is_active, created_at) FROM stdin;
1	Deadly One	financial	30.00	300	f	2026-06-05 13:41:15.644116
\.


--
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.roles (id, name) FROM stdin;
1	ROLE_ADMIN
2	ROLE_OPERATOR
3	ROLE_FINANCE
4	ROLE_CUSTOMER
\.


--
-- Data for Name: tariff_tiers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tariff_tiers (id, tariff_id, min_consumption, max_consumption, rate, description) FROM stdin;
1	1	0.00	99999.00	350.0000	Flat rate water
2	2	0.00	20.00	2.0000	N/A
3	3	0.00	20.00	2.0000	N/A
\.


--
-- Data for Name: tariffs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tariffs (id, meter_type, tariff_type, version, effective_from, effective_to, is_active, created_at) FROM stdin;
1	WATER	FLAT	1	2026-01-01	2026-06-09	f	2026-06-05 12:00:28.025514
3	WATER	FLAT	3	2026-06-05	\N	t	2026-06-05 13:31:57.93977
2	WATER	FLAT	2	2026-06-10	2026-06-04	f	2026-06-05 12:38:04.330695
\.


--
-- Data for Name: taxes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.taxes (id, tax_name, tax_type, percentage, is_active, created_at) FROM stdin;
1	VAT	VALUE_ADDED_TAX	18.00	t	2026-06-05 12:01:45.436982
2	BAT	BILLING_ADDED_TAX	2.00	t	2026-06-05 13:07:56.526291
\.


--
-- Data for Name: user_roles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_roles (user_id, role_id) FROM stdin;
1	1
2	2
3	3
4	4
5	4
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, full_names, email, phone_number, password, status, created_at, updated_at) FROM stdin;
1	System Administrator	admin@utilitybilling.rw	+250788000000	$2a$10$iCU1bLmOMxuAM2JJupWfbe4I6pjF3elPsMYcEme1puDeQ6dMMuTBC	ACTIVE	2026-06-05 11:43:03.89254	2026-06-05 11:43:03.89254
2	Meter Operator	operator@utilitybilling.rw	+250788000001	$2a$10$vOQBMBGPvd.WW.NndCv0lOPmJp/tH7PcRBkRoP9Ml1bPyFD8cBgL6	ACTIVE	2026-06-05 11:43:03.973554	2026-06-05 11:43:03.97454
3	Finance Officer	finance@utilitybilling.rw	+250788000002	$2a$10$v0Y8p6/tiVwZ50Hf52itruJsoAkoRvM2ZRfEuio2Czgc5b7w7pzWy	ACTIVE	2026-06-05 11:43:04.02954	2026-06-05 11:43:04.02954
4	MUHIRWA Reine Kheira	reinekheira2023@gmail.com	0788567385	$2a$10$quuVLgu65YfOORUVgqQhQOlkc3eAa2hOTjHpg2blRy5X8nyGCKH2.	ACTIVE	2026-06-05 12:29:07.229953	2026-06-05 12:31:55.475488
5	IRAMBONA Eric	eric@gmail.com	0734261824	$2a$10$kaWU..eQGMj6cpLs2SIiceVCbyA2sggNQGQJ1e2iYSinjD48h2myi	ACTIVE	2026-06-05 14:20:39.982767	2026-06-05 14:20:39.982767
\.


--
-- Name: bills_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.bills_id_seq', 2, true);


--
-- Name: customers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.customers_id_seq', 4, true);


--
-- Name: fixed_charges_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.fixed_charges_id_seq', 2, true);


--
-- Name: meter_readings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.meter_readings_id_seq', 2, true);


--
-- Name: meters_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.meters_id_seq', 2, true);


--
-- Name: notifications_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.notifications_id_seq', 3, true);


--
-- Name: payments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.payments_id_seq', 2, true);


--
-- Name: penalties_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.penalties_id_seq', 1, true);


--
-- Name: roles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.roles_id_seq', 4, true);


--
-- Name: tariff_tiers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tariff_tiers_id_seq', 3, true);


--
-- Name: tariffs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tariffs_id_seq', 3, true);


--
-- Name: taxes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.taxes_id_seq', 2, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 5, true);


--
-- Name: bills bills_bill_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills
    ADD CONSTRAINT bills_bill_number_key UNIQUE (bill_number);


--
-- Name: bills bills_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills
    ADD CONSTRAINT bills_pkey PRIMARY KEY (id);


--
-- Name: customers customers_national_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_national_id_key UNIQUE (national_id);


--
-- Name: customers customers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (id);


--
-- Name: fixed_charges fixed_charges_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fixed_charges
    ADD CONSTRAINT fixed_charges_pkey PRIMARY KEY (id);


--
-- Name: meter_readings meter_readings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.meter_readings
    ADD CONSTRAINT meter_readings_pkey PRIMARY KEY (id);


--
-- Name: meters meters_meter_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.meters
    ADD CONSTRAINT meters_meter_number_key UNIQUE (meter_number);


--
-- Name: meters meters_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.meters
    ADD CONSTRAINT meters_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: penalties penalties_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.penalties
    ADD CONSTRAINT penalties_pkey PRIMARY KEY (id);


--
-- Name: roles roles_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_name_key UNIQUE (name);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: tariff_tiers tariff_tiers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tariff_tiers
    ADD CONSTRAINT tariff_tiers_pkey PRIMARY KEY (id);


--
-- Name: tariffs tariffs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tariffs
    ADD CONSTRAINT tariffs_pkey PRIMARY KEY (id);


--
-- Name: taxes taxes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.taxes
    ADD CONSTRAINT taxes_pkey PRIMARY KEY (id);


--
-- Name: meter_readings uq_meter_month_year; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.meter_readings
    ADD CONSTRAINT uq_meter_month_year UNIQUE (meter_id, reading_month, reading_year);


--
-- Name: tariffs uq_tariff_version; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tariffs
    ADD CONSTRAINT uq_tariff_version UNIQUE (meter_type, version);


--
-- Name: user_roles user_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (user_id, role_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: bills trg_bill_notification; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_bill_notification AFTER INSERT ON public.bills FOR EACH ROW EXECUTE FUNCTION public.generate_bill_notification();


--
-- Name: payments trg_payment_update_bill; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_payment_update_bill AFTER INSERT ON public.payments FOR EACH ROW EXECUTE FUNCTION public.on_payment_update_bill();


--
-- Name: bills bills_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills
    ADD CONSTRAINT bills_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.users(id);


--
-- Name: bills bills_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills
    ADD CONSTRAINT bills_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: bills bills_meter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills
    ADD CONSTRAINT bills_meter_id_fkey FOREIGN KEY (meter_id) REFERENCES public.meters(id);


--
-- Name: bills bills_meter_reading_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bills
    ADD CONSTRAINT bills_meter_reading_id_fkey FOREIGN KEY (meter_reading_id) REFERENCES public.meter_readings(id);


--
-- Name: customers customers_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: meter_readings meter_readings_captured_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.meter_readings
    ADD CONSTRAINT meter_readings_captured_by_fkey FOREIGN KEY (captured_by) REFERENCES public.users(id);


--
-- Name: meter_readings meter_readings_meter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.meter_readings
    ADD CONSTRAINT meter_readings_meter_id_fkey FOREIGN KEY (meter_id) REFERENCES public.meters(id);


--
-- Name: meters meters_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.meters
    ADD CONSTRAINT meters_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: notifications notifications_bill_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_bill_id_fkey FOREIGN KEY (bill_id) REFERENCES public.bills(id);


--
-- Name: notifications notifications_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: payments payments_bill_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_bill_id_fkey FOREIGN KEY (bill_id) REFERENCES public.bills(id);


--
-- Name: payments payments_processed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_processed_by_fkey FOREIGN KEY (processed_by) REFERENCES public.users(id);


--
-- Name: tariff_tiers tariff_tiers_tariff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tariff_tiers
    ADD CONSTRAINT tariff_tiers_tariff_id_fkey FOREIGN KEY (tariff_id) REFERENCES public.tariffs(id) ON DELETE CASCADE;


--
-- Name: user_roles user_roles_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- Name: user_roles user_roles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: bills; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.bills ENABLE ROW LEVEL SECURITY;

--
-- Name: customers; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;

--
-- Name: fixed_charges; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.fixed_charges ENABLE ROW LEVEL SECURITY;

--
-- Name: meter_readings; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.meter_readings ENABLE ROW LEVEL SECURITY;

--
-- Name: meters; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.meters ENABLE ROW LEVEL SECURITY;

--
-- Name: notifications; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

--
-- Name: payments; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

--
-- Name: penalties; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.penalties ENABLE ROW LEVEL SECURITY;

--
-- Name: roles; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;

--
-- Name: tariff_tiers; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.tariff_tiers ENABLE ROW LEVEL SECURITY;

--
-- Name: tariffs; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.tariffs ENABLE ROW LEVEL SECURITY;

--
-- Name: taxes; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.taxes ENABLE ROW LEVEL SECURITY;

--
-- Name: user_roles; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

--
-- PostgreSQL database dump complete
--

\unrestrict NHwLar05hw2VgFNdvbR4WuBOqwGYMTEBkwNNCIAD7kbqHzy3ghK4OXzXwczV2yU

