# Utility Billing System - ERD & System Documentation

## Entity Relationship Diagram (ERD)

```
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│     USERS        │       │     ROLES       │       │   USER_ROLES    │
├─────────────────┤       ├─────────────────┤       ├─────────────────┤
│ PK id            │───────│ PK id            │──────│ FK user_id      │
│ full_names       │       │ name             │       │ FK role_id      │
│ email (unique)   │       └─────────────────┘       └─────────────────┘
│ phone_number     │              │
│ password         │              │ (roles assigned to user)
│ status           │              ▼
│ created_at       │       ┌─────────────────┐
│ updated_at       │       │   CUSTOMERS     │
└─────────────────┘       ├─────────────────┤
                           │ PK id            │
                           │ full_names       │
                           │ national_id(UQ)  │
                           │ email            │
                           │ phone_number     │
                           │ address          │
                           │ status           │
                           │ FK user_id       │──┐
                           │ created_at       │  │
                           │ updated_at       │  │
                           └─────────────────┘  │
                                                  │
                           ┌─────────────────┐  │
                           │    METERS       │  │
                           ├─────────────────┤  │
                  ┌───────│ PK id            │  │
                  │       │ meter_number(UQ) │  │
                  │       │ meter_type       │  │
                  │       │ installation_date│  │
                  │       │ status           │  │
                  │       │ FK customer_id ──│──┘
                  │       │ created_at       │
                  │       │ updated_at       │
                  │       └─────────────────┘
                  │
                  │       ┌──────────────────────┐
                  │       │   METER_READINGS      │
                  │       ├──────────────────────┤
                  ├───M──│ PK id                 │
                  │       │ FK meter_id           │
                  │       │ previous_reading      │
                  │       │ current_reading       │
                  │       │ reading_date          │
                  │       │ reading_month         │
                  │       │ reading_year          │
                  │       │ FK captured_by        │──► USERS
                  │       │ created_at            │
                  │       └──────────────────────┘
                  │                    │
                  │                    │ (reading used for bill)
                  │                    ▼
                  │       ┌──────────────────────┐        ┌─────────────────┐
                  │       │      BILLS           │        │   PAYMENTS      │
                  │       ├──────────────────────┤        ├─────────────────┤
                  │  ┌──M│ PK id                │──M──┐  │ PK id            │
                  │  │   │ bill_number (UQ)     │     │  │ FK bill_id       │
                  │  │   │ FK customer_id ──────│──┐  │  │ amount_paid      │
                  │  │   │ FK meter_id ─────────│──┼──│──│ payment_method   │
                  │  │   │ FK meter_reading_id  │  │  │  │ payment_date     │
                  │  │   │ billing_month        │  │  │  │ reference_number │
                  │  │   │ billing_year         │  │  │  │ FK processed_by  │──► USERS
                  │  │   │ consumption          │  │  │  │ created_at       │
                  │  │   │ tariff_charge        │  │  │  └─────────────────┘
                  │  │   │ fixed_charge         │  │  │
                  │  │   │ tax_amount           │  │  │  ┌──────────────────────┐
                  │  │   │ penalty_amount       │  │  │  │   NOTIFICATIONS      │
                  │  │   │ total_amount         │  │  │  ├──────────────────────┤
                  │  │   │ outstanding_balance  │  │  └──│ PK id                │
                  │  │   │ bill_status          │  │     │ FK customer_id       │
                  │  │   │ due_date             │  │     │ FK bill_id           │
                  │  │   │ FK approved_by ──────│──┼──►USERS│ message           │
                  │  │   │ approved_at          │  │     │ notification_type    │
                  │  │   │ generated_at         │  │     │ is_read             │
                  │  │   │ created_at           │  │     │ created_at           │
                  │  │   │ updated_at           │  │     └──────────────────────┘
                  │  │   └──────────────────────┘  │
                  │  │                              │
                  │  │   ┌─────────────────┐        │
                  │  │   │    TARIFFS      │        │
                  │  │   ├─────────────────┤        │
                  │  │   │ PK id            │        │
                  │  │   │ meter_type       │        │
                  │  │   │ tariff_type      │        │
                  │  │   │ version          │        │
                  │  │   │ effective_from   │        │
                  │  │   │ effective_to     │        │
                  │  │   │ is_active        │        │
                  │  │   │ created_at       │        │
                  │  │   └───────┬─────────┘        │
                  │  │           │ 1:N               │
                  │  │           ▼                    │
                  │  │   ┌─────────────────┐        │
                  │  │   │  TARIFF_TIERS   │        │
                  │  │   ├─────────────────┤        │
                  │  │   │ PK id            │        │
                  │  │   │ FK tariff_id     │        │
                  │  │   │ min_consumption  │        │
                  │  │   │ max_consumption  │        │
                  │  │   │ rate             │        │
                  │  │   │ description      │        │
                  │  │   └─────────────────┘        │
                  │  │                              │
                  │  │   ┌─────────────────┐        │
                  │  │   │ FIXED_CHARGES   │        │
                  │  │   ├─────────────────┤        │
                  │  │   │ PK id            │        │
                  │  │   │ meter_type       │        │
                  │  │   │ charge_name      │        │
                  │  │   │ amount           │        │
                  │  │   │ version          │        │
                  │  │   │ effective_from   │        │
                  │  │   │ effective_to     │        │
                  │  │   │ is_active        │        │
                  │  │   └─────────────────┘        │
                  │  │                              │
                  │  │   ┌─────────────────┐        │
                  │  │   │     TAXES       │        │
                  │  │   ├─────────────────┤        │
                  │  │   │ PK id            │        │
                  │  │   │ tax_name         │        │
                  │  │   │ tax_type         │        │
                  │  │   │ percentage       │        │
                  │  │   │ is_active        │        │
                  │  │   └─────────────────┘        │
                  │  │                              │
                  │  │   ┌─────────────────┐        │
                  │  │   │   PENALTIES     │        │
                  │  │   ├─────────────────┤        │
                  │  │   │ PK id            │        │
                  │  │   │ penalty_name     │        │
                  │  │   │ penalty_type     │        │
                  │  │   │ percentage       │        │
                  │  │   │ grace_period_days│        │
                  │  │   │ is_active        │        │
                  │  │   └─────────────────┘        │
                  │  │                              │
                  └──┴────────────────────────────────┘
                      (customer relationship chain)
```

## Relationships Summary

| Entity | Relationship | Target |
|--------|-------------|--------|
| User | M:N | Role (via user_roles) |
| Customer | M:1 | User (optional link) |
| Customer | 1:N | Meter |
| Meter | 1:N | MeterReading |
| MeterReading | 1:1 | Bill |
| Customer | 1:N | Bill |
| Bill | 1:N | Payment |
| Customer | 1:N | Notification |
| Tariff | 1:N | TariffTier |

## Cardinality

- One Customer can have **many** Meters (1:N)
- One Meter can have **many** MeterReadings, but only **one per month/year** (1:N with constraint)
- One MeterReading produces **one** Bill (1:1)
- One Bill can have **many** Payments (1:N) — supports partial payments
- One Customer can have **many** Bills (1:N)
- One Customer can have **many** Notifications (1:N)
- One Tariff can have **many** Tiers (1:N)

---

## Spring Boot Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        CLIENT (Postman/Swagger)                     │
└───────────────────────────┬─────────────────────────────────────────┘
                            │ HTTP Requests (JSON)
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     SPRING SECURITY FILTER CHAIN                     │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐    │
│  │ AuthEntryPointJwt│  │ AuthTokenFilter  │  │ SecurityConfig   │    │
│  │ (401 responses)  │  │ (JWT validation) │  │ (URL rules)      │    │
│  └─────────────────┘  └────────┬────────┘  └─────────────────┘    │
└─────────────────────────────────┼───────────────────────────────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    │  /api/auth/** = PUBLIC     │
                    │  All others = AUTHENTICATED│
                    └─────────────┬─────────────┘
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         CONTROLLERS                                  │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌────────────┐ │
│  │AuthController │ │CustomerCtrl  │ │ MeterCtrl    │ │ReadingCtrl │ │
│  │ /api/auth/*  │ │ /api/cust/*  │ │ /api/meters/*│ │/api/read/*│ │
│  └──────┬───────┘ └──────┬───────┘ └──────┬───────┘ └─────┬──────┘ │
│  ┌──────┴───────┐ ┌──────┴───────┐ ┌──────┴───────┐ ┌─────┴──────┐ │
│  │TariffCtrl    │ │FixedChrgCtrl │ │ TaxCtrl      │ │PenaltyCtrl │ │
│  │ /api/tariffs │ │/api/fixed-*  │ │ /api/taxes/* │ │/api/pen/* │ │
│  └──────┬───────┘ └──────┬───────┘ └──────┬───────┘ └─────┬──────┘ │
│  ┌──────┴───────┐ ┌──────┴───────┐ ┌──────┴───────┐                   │
│  │BillCtrl      │ │PaymentCtrl   │ │NotifCtrl     │                   │
│  │ /api/bills/* │ │/api/payments │ │/api/notif/*  │                   │
│  └──────┬───────┘ └──────┬───────┘ └──────┬───────┘                   │
└─────────┼────────────────┼────────────────┼───────────────────────────┘
          │                │                │
          ▼                ▼                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          SERVICES                                    │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐         │
│  │AuthService │ │CustService│ │MeterSvc   │ │ReadingSvc │         │
│  └─────┬─────┘ └─────┬─────┘ └─────┬─────┘ └─────┬─────┘         │
│  ┌─────┴─────┐ ┌─────┴─────┐ ┌─────┴─────┐ ┌─────┴─────┐         │
│  │TariffSvc  │ │BillSvc    │ │PaymentSvc │ │NotifSvc   │         │
│  └─────┬─────┘ └─────┬─────┘ └─────┬─────┘ └─────┬─────┘         │
└────────┼──────────────┼──────────────┼──────────────┼───────────────┘
         │              │              │              │
         ▼              ▼              ▼              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       REPOSITORIES (Spring Data JPA)                 │
│  UserRepo  RoleRepo  CustomerRepo  MeterRepo  MeterReadingRepo     │
│  TariffRepo TariffTierRepo  FixedChargeRepo  TaxRepo  PenaltyRepo  │
│  BillRepo  PaymentRepo  NotificationRepo                           │
└───────────────────────────┬─────────────────────────────────────────┘
                            │ JPA/Hibernate
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    POSTGRESQL DATABASE (Supabase)                    │
│                                                                      │
│  TABLES: users, roles, user_roles, customers, meters,               │
│          meter_readings, tariffs, tariff_tiers, fixed_charges,      │
│          taxes, penalties, bills, payments, notifications           │
│                                                                      │
│  TRIGGERS:                                                           │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ trg_bill_notification: AFTER INSERT ON bills                │    │
│  │   → Inserts notification message for customer               │    │
│  │   → Format: "Dear <Name>, Your <Month/Year> utility bill   │    │
│  │     of <Amount> FRW has been successfully processed."       │    │
│  └─────────────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ trg_payment_update_bill: AFTER INSERT ON payments           │    │
│  │   → Updates bill outstanding_balance & status               │    │
│  │   → If fully paid: status = PAID, insert notification       │    │
│  │   → If partially: status = PARTIALLY_PAID                   │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  STORED PROCEDURES:                                                  │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ sp_generate_bill(reading_id, due_date, approver_id)         │    │
│  │   → Calculates consumption, tariff, fixed charge, tax,      │    │
│  │     penalty → Inserts bill → Trigger fires notification     │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

## Role-Based Access Matrix

| API Endpoint | ADMIN | OPERATOR | FINANCE | CUSTOMER |
|-------------|-------|----------|---------|----------|
| POST /api/auth/signup | Yes | - | - | - |
| POST /api/auth/login | Public | Public | Public | Public |
| GET /api/auth/users | Yes | - | Yes | - |
| POST /api/customers | Yes | - | - | - |
| GET /api/customers | Yes | Yes | Yes | - |
| POST /api/meters | Yes | - | - | - |
| GET /api/meters | Yes | Yes | Yes | - |
| POST /api/meter-readings | - | Yes | - | - |
| GET /api/meter-readings | Yes | Yes | Yes | - |
| POST /api/tariffs | Yes | - | - | - |
| GET /api/tariffs | Yes | Yes | Yes | - |
| POST /api/fixed-charges | Yes | - | - | - |
| POST /api/taxes | Yes | - | - | - |
| POST /api/penalties | Yes | - | - | - |
| POST /api/bills/generate | Yes | - | Yes | - |
| PUT /api/bills/{id}/approve | Yes | - | Yes | - |
| GET /api/bills | Yes | - | Yes | - |
| GET /api/bills/customer/{id} | Yes | - | Yes | Yes |
| POST /api/payments | Yes | - | Yes | - |
| GET /api/payments/customer/{id} | Yes | - | Yes | Yes |
| GET /api/notifications/customer/{id} | Yes | - | - | Yes |
