-- ===========================================
-- UTILITY BILLING SYSTEM - DATABASE SCHEMA
-- ===========================================

-- 1. USERS table (for JWT auth)
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    full_names VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone_number VARCHAR(50),
    password VARCHAR(255) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 2. ROLES table
CREATE TABLE roles (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL
);

-- 3. USER_ROLES junction table
CREATE TABLE user_roles (
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id BIGINT NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, role_id)
);

-- 4. CUSTOMERS table
CREATE TABLE customers (
    id BIGSERIAL PRIMARY KEY,
    full_names VARCHAR(255) NOT NULL,
    national_id VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) NOT NULL,
    phone_number VARCHAR(50) NOT NULL,
    address TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    user_id BIGINT REFERENCES users(id),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 5. METERS table
CREATE TABLE meters (
    id BIGSERIAL PRIMARY KEY,
    meter_number VARCHAR(100) UNIQUE NOT NULL,
    meter_type VARCHAR(20) NOT NULL CHECK (meter_type IN ('WATER', 'ELECTRICITY')),
    installation_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    customer_id BIGINT NOT NULL REFERENCES customers(id),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 6. METER_READINGS table
CREATE TABLE meter_readings (
    id BIGSERIAL PRIMARY KEY,
    meter_id BIGINT NOT NULL REFERENCES meters(id),
    previous_reading DECIMAL(15,2) NOT NULL,
    current_reading DECIMAL(15,2) NOT NULL,
    reading_date DATE NOT NULL,
    reading_month INT NOT NULL CHECK (reading_month BETWEEN 1 AND 12),
    reading_year INT NOT NULL,
    captured_by BIGINT NOT NULL REFERENCES users(id),
    created_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT chk_reading_positive CHECK (current_reading > previous_reading),
    CONSTRAINT uq_meter_month_year UNIQUE (meter_id, reading_month, reading_year)
);

-- 7. TARIFFS table (versioned)
CREATE TABLE tariffs (
    id BIGSERIAL PRIMARY KEY,
    meter_type VARCHAR(20) NOT NULL CHECK (meter_type IN ('WATER', 'ELECTRICITY')),
    tariff_type VARCHAR(20) NOT NULL CHECK (tariff_type IN ('FLAT', 'TIERED')),
    version INT NOT NULL DEFAULT 1,
    effective_from DATE NOT NULL,
    effective_to DATE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT uq_tariff_version UNIQUE (meter_type, version)
);

-- 8. TARIFF_TIERS table (for tier-based tariffs)
CREATE TABLE tariff_tiers (
    id BIGSERIAL PRIMARY KEY,
    tariff_id BIGINT NOT NULL REFERENCES tariffs(id) ON DELETE CASCADE,
    min_consumption DECIMAL(15,2) NOT NULL DEFAULT 0,
    max_consumption DECIMAL(15,2),
    rate DECIMAL(15,4) NOT NULL,
    description VARCHAR(255)
);

-- 9. FIXED_CHARGES table
CREATE TABLE fixed_charges (
    id BIGSERIAL PRIMARY KEY,
    meter_type VARCHAR(20) NOT NULL CHECK (meter_type IN ('WATER', 'ELECTRICITY')),
    charge_name VARCHAR(255) NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    version INT NOT NULL DEFAULT 1,
    effective_from DATE NOT NULL,
    effective_to DATE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 10. TAXES table
CREATE TABLE taxes (
    id BIGSERIAL PRIMARY KEY,
    tax_name VARCHAR(255) NOT NULL,
    tax_type VARCHAR(50) NOT NULL,
    percentage DECIMAL(5,2) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 11. PENALTIES table
CREATE TABLE penalties (
    id BIGSERIAL PRIMARY KEY,
    penalty_name VARCHAR(255) NOT NULL,
    penalty_type VARCHAR(50) NOT NULL,
    percentage DECIMAL(5,2) NOT NULL,
    grace_period_days INT NOT NULL DEFAULT 30,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 12. BILLS table
CREATE TABLE bills (
    id BIGSERIAL PRIMARY KEY,
    bill_number VARCHAR(100) UNIQUE NOT NULL,
    customer_id BIGINT NOT NULL REFERENCES customers(id),
    meter_id BIGINT NOT NULL REFERENCES meters(id),
    meter_reading_id BIGINT NOT NULL REFERENCES meter_readings(id),
    billing_month INT NOT NULL,
    billing_year INT NOT NULL,
    consumption DECIMAL(15,2) NOT NULL,
    tariff_charge DECIMAL(15,2) NOT NULL DEFAULT 0,
    fixed_charge DECIMAL(15,2) NOT NULL DEFAULT 0,
    tax_amount DECIMAL(15,2) NOT NULL DEFAULT 0,
    penalty_amount DECIMAL(15,2) NOT NULL DEFAULT 0,
    total_amount DECIMAL(15,2) NOT NULL,
    outstanding_balance DECIMAL(15,2) NOT NULL,
    bill_status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    due_date DATE NOT NULL,
    approved_by BIGINT REFERENCES users(id),
    approved_at TIMESTAMP,
    generated_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 13. PAYMENTS table
CREATE TABLE payments (
    id BIGSERIAL PRIMARY KEY,
    bill_id BIGINT NOT NULL REFERENCES bills(id),
    amount_paid DECIMAL(15,2) NOT NULL,
    payment_method VARCHAR(50) NOT NULL,
    payment_date TIMESTAMP NOT NULL DEFAULT NOW(),
    reference_number VARCHAR(255),
    processed_by BIGINT REFERENCES users(id),
    created_at TIMESTAMP DEFAULT NOW()
);

-- 14. NOTIFICATIONS table
CREATE TABLE notifications (
    id BIGSERIAL PRIMARY KEY,
    customer_id BIGINT NOT NULL REFERENCES customers(id),
    bill_id BIGINT REFERENCES bills(id),
    message TEXT NOT NULL,
    notification_type VARCHAR(50) NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert default roles
INSERT INTO roles (name) VALUES ('ROLE_ADMIN'), ('ROLE_OPERATOR'), ('ROLE_FINANCE'), ('ROLE_CUSTOMER');

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE meters ENABLE ROW LEVEL SECURITY;
ALTER TABLE meter_readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE tariffs ENABLE ROW LEVEL SECURITY;
ALTER TABLE tariff_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE fixed_charges ENABLE ROW LEVEL SECURITY;
ALTER TABLE taxes ENABLE ROW LEVEL SECURITY;
ALTER TABLE penalties ENABLE ROW LEVEL SECURITY;
ALTER TABLE bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- RLS Policies - backend uses service_role key for full access
CREATE POLICY "service_all_users" ON users FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "service_all_roles" ON roles FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "service_all_user_roles" ON user_roles FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "service_all_customers" ON customers FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "service_all_meters" ON meters FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "service_all_meter_readings" ON meter_readings FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "service_all_tariffs" ON tariffs FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "service_all_tariff_tiers" ON tariff_tiers FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "service_all_fixed_charges" ON fixed_charges FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "service_all_taxes" ON taxes FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "service_all_penalties" ON penalties FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "service_all_bills" ON bills FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "service_all_payments" ON payments FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "service_all_notifications" ON notifications FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ===========================================
-- TRIGGER: On bill generation, insert notification
-- ===========================================
CREATE OR REPLACE FUNCTION generate_bill_notification()
RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_bill_notification
AFTER INSERT ON bills
FOR EACH ROW
EXECUTE FUNCTION generate_bill_notification();

-- ===========================================
-- TRIGGER: On full payment, update bill status and notify customer
-- ===========================================
CREATE OR REPLACE FUNCTION on_payment_update_bill()
RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_payment_update_bill
AFTER INSERT ON payments
FOR EACH ROW
EXECUTE FUNCTION on_payment_update_bill();

-- ===========================================
-- STORED PROCEDURE: Generate bill for a meter reading
-- ===========================================
CREATE OR REPLACE PROCEDURE sp_generate_bill(
    p_meter_reading_id BIGINT,
    p_due_date DATE,
    p_approved_by BIGINT
)
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
