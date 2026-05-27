-- ============================================================
-- JIRETA LOANS & CREDIT CORP. 1996
-- Sta. Barbara, Pangasinan
-- PostgreSQL Schema — Third Normal Form (3NF)
-- lending1system
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================================
-- ENUMS
-- ============================================================

CREATE TYPE user_role_enum AS ENUM ('head_manager', 'employee', 'rider', 'lender');

CREATE TYPE gender_enum AS ENUM ('male', 'female', 'prefer_not_to_say');

CREATE TYPE civil_status_enum AS ENUM ('single', 'married', 'widowed', 'separated', 'annulled');

CREATE TYPE loan_status_enum AS ENUM (
  'pending', 'under_ci', 'approved', 'rejected',
  'active', 'overdue', 'completed', 'frozen'
);

CREATE TYPE payment_frequency_enum AS ENUM ('daily', 'weekly', 'monthly');

CREATE TYPE collection_status_enum AS ENUM (
  'pending', 'assigned', 'collecting', 'completed', 'failed'
);

CREATE TYPE ci_status_enum AS ENUM (
  'pending', 'assigned', 'ongoing', 'reviewed', 'approved', 'rejected'
);

CREATE TYPE document_type_enum AS ENUM (
  'valid_id', 'psa', 'mayors_permit', 'proof_of_income',
  'business_permit', 'barangay_clearance', 'utility_bill',
  'land_title', 'vehicle_or', 'supporting_document'
);

CREATE TYPE notification_type_enum AS ENUM (
  'loan_approved', 'loan_rejected', 'payment_due', 'payment_received',
  'overdue_alert', 'penalty_applied', 'ci_assigned', 'ci_completed',
  'account_suspended', 'account_restored', 'system_alert',
  'rider_assigned', 'collection_completed', 'document_required'
);

CREATE TYPE payment_method_enum AS ENUM (
  'gcash', 'maya', 'qrph', 'credit_card', 'debit_card', 'cash_collection'
);

CREATE TYPE payment_status_enum AS ENUM (
  'pending', 'processing', 'completed', 'failed', 'refunded', 'cancelled'
);

CREATE TYPE account_status_enum AS ENUM (
  'active', 'suspended', 'pending_verification', 'deactivated'
);

CREATE TYPE charge_type_enum AS ENUM (
  'processing_fee', 'service_fee', 'ci_fee', 'penalty_fee',
  'late_fee', 'notarial_fee', 'insurance_fee', 'miscellaneous'
);

CREATE TYPE audit_action_enum AS ENUM (
  'create', 'read', 'update', 'delete', 'archive', 'restore',
  'login', 'logout', 'approve', 'reject', 'suspend', 'assign',
  'payment', 'refund', 'export', 'import'
);

-- ============================================================
-- TABLE: roles
-- ============================================================
CREATE TABLE roles (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name         user_role_enum NOT NULL UNIQUE,
  display_name VARCHAR(100) NOT NULL,
  description  TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: permissions
-- ============================================================
CREATE TABLE permissions (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code         VARCHAR(100) NOT NULL UNIQUE,
  name         VARCHAR(150) NOT NULL,
  module       VARCHAR(100) NOT NULL,
  description  TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: role_permissions (pivot)
-- ============================================================
CREATE TABLE role_permissions (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  role_id       UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(role_id, permission_id)
);

-- ============================================================
-- TABLE: users
-- ============================================================
CREATE TABLE users (
  id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  auth_id              UUID UNIQUE,
  role_id              UUID NOT NULL REFERENCES roles(id),
  email                VARCHAR(254) NOT NULL UNIQUE,
  first_name           VARCHAR(100) NOT NULL,
  middle_name          VARCHAR(100),
  last_name            VARCHAR(100) NOT NULL,
  suffix               VARCHAR(20),
  phone_number         VARCHAR(15) NOT NULL,
  gender               gender_enum NOT NULL,
  civil_status         civil_status_enum NOT NULL,
  date_of_birth        DATE NOT NULL,
  profile_picture_url  TEXT,
  account_status       account_status_enum NOT NULL DEFAULT 'pending_verification',
  email_verified_at    TIMESTAMPTZ,
  last_login_at        TIMESTAMPTZ,
  last_active_at       TIMESTAMPTZ,
  fcm_token            TEXT,
  created_by           UUID REFERENCES users(id),
  updated_by           UUID REFERENCES users(id),
  is_archived          BOOLEAN NOT NULL DEFAULT FALSE,
  archived_at          TIMESTAMPTZ,
  archived_by          UUID REFERENCES users(id),
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: user_roles (pivot — supports multiple roles in future)
-- ============================================================
CREATE TABLE user_roles (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role_id    UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  granted_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, role_id)
);

-- ============================================================
-- TABLE: addresses
-- ============================================================
CREATE TABLE addresses (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  address_type VARCHAR(50) NOT NULL DEFAULT 'primary',
  street       VARCHAR(255) NOT NULL,
  barangay     VARCHAR(100) NOT NULL,
  municipality VARCHAR(100) NOT NULL,
  province     VARCHAR(100) NOT NULL,
  region       VARCHAR(100) NOT NULL DEFAULT 'Region I - Ilocos Region',
  zip_code     VARCHAR(10) NOT NULL,
  country      VARCHAR(100) NOT NULL DEFAULT 'Philippines',
  latitude     DECIMAL(10,8),
  longitude    DECIMAL(11,8),
  is_primary   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: employees
-- ============================================================
CREATE TABLE employees (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  employee_code     VARCHAR(30) NOT NULL UNIQUE,
  position          VARCHAR(100) NOT NULL,
  department        VARCHAR(100) NOT NULL DEFAULT 'Operations',
  date_hired        DATE NOT NULL,
  employment_status VARCHAR(50) NOT NULL DEFAULT 'regular',
  supervisor_id     UUID REFERENCES employees(id),
  can_approve_loans BOOLEAN NOT NULL DEFAULT FALSE,
  max_approval_amt  DECIMAL(12,2) NOT NULL DEFAULT 0,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: riders
-- ============================================================
CREATE TABLE riders (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id             UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  rider_code          VARCHAR(30) NOT NULL UNIQUE,
  license_number      VARCHAR(50) NOT NULL,
  license_expiry      DATE NOT NULL,
  vehicle_type        VARCHAR(50) NOT NULL,
  vehicle_plate       VARCHAR(20) NOT NULL,
  vehicle_model       VARCHAR(100) NOT NULL,
  vehicle_year        INT NOT NULL,
  current_latitude    DECIMAL(10,8),
  current_longitude   DECIMAL(11,8),
  last_location_at    TIMESTAMPTZ,
  is_available        BOOLEAN NOT NULL DEFAULT TRUE,
  total_collections   INT NOT NULL DEFAULT 0,
  total_amount_col    DECIMAL(15,2) NOT NULL DEFAULT 0,
  managed_by          UUID REFERENCES employees(id),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: lenders (borrowers)
-- ============================================================
CREATE TABLE lenders (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id               UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  lender_code           VARCHAR(30) NOT NULL UNIQUE,
  occupation            VARCHAR(100) NOT NULL,
  employer_name         VARCHAR(200),
  monthly_income        DECIMAL(12,2) NOT NULL,
  source_of_income      VARCHAR(100) NOT NULL,
  credit_score          INT NOT NULL DEFAULT 0,
  risk_level            VARCHAR(20) NOT NULL DEFAULT 'unrated',
  is_blacklisted        BOOLEAN NOT NULL DEFAULT FALSE,
  blacklisted_at        TIMESTAMPTZ,
  blacklisted_by        UUID REFERENCES users(id),
  blacklist_reason      TEXT,
  total_loans           INT NOT NULL DEFAULT 0,
  active_loan_count     INT NOT NULL DEFAULT 0,
  total_paid_amount     DECIMAL(15,2) NOT NULL DEFAULT 0,
  total_overdue_count   INT NOT NULL DEFAULT 0,
  kyc_verified          BOOLEAN NOT NULL DEFAULT FALSE,
  kyc_verified_at       TIMESTAMPTZ,
  kyc_verified_by       UUID REFERENCES users(id),
  referral_source       VARCHAR(100),
  emergency_contact_name   VARCHAR(200) NOT NULL,
  emergency_contact_phone  VARCHAR(15) NOT NULL,
  emergency_contact_rel    VARCHAR(50) NOT NULL,
  business_name         VARCHAR(200),
  business_type         VARCHAR(100),
  business_address      TEXT,
  years_in_business     INT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: lender_documents
-- ============================================================
CREATE TABLE lender_documents (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  lender_id     UUID NOT NULL REFERENCES lenders(id) ON DELETE CASCADE,
  document_type document_type_enum NOT NULL,
  file_name     VARCHAR(255) NOT NULL,
  file_url      TEXT NOT NULL,
  file_size     BIGINT NOT NULL,
  mime_type     VARCHAR(100) NOT NULL,
  is_verified   BOOLEAN NOT NULL DEFAULT FALSE,
  verified_by   UUID REFERENCES users(id),
  verified_at   TIMESTAMPTZ,
  remarks       TEXT,
  is_archived   BOOLEAN NOT NULL DEFAULT FALSE,
  archived_at   TIMESTAMPTZ,
  archived_by   UUID REFERENCES users(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: loan_settings (configurable by Head Manager)
-- ============================================================
CREATE TABLE loan_settings (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  setting_key           VARCHAR(100) NOT NULL UNIQUE,
  setting_value         TEXT NOT NULL,
  setting_type          VARCHAR(50) NOT NULL DEFAULT 'decimal',
  description           TEXT,
  updated_by            UUID REFERENCES users(id),
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Default settings seed
INSERT INTO loan_settings (setting_key, setting_value, setting_type, description) VALUES
  ('default_interest_rate',   '20',        'decimal',  'Default interest rate percentage'),
  ('min_loan_amount',         '5000',      'decimal',  'Minimum loan amount in PHP'),
  ('max_loan_amount',         '500000',    'decimal',  'Maximum loan amount in PHP'),
  ('processing_fee_rate',     '2',         'decimal',  'Processing fee percentage'),
  ('service_fee_rate',        '1',         'decimal',  'Service fee percentage'),
  ('ci_fee_flat',             '500',       'decimal',  'CI fee flat amount in PHP'),
  ('penalty_rate_daily',      '0.5',       'decimal',  'Daily penalty rate percentage for overdue'),
  ('grace_period_days',       '3',         'integer',  'Grace period before penalty applies'),
  ('session_timeout_minutes', '10',        'integer',  'Lender session timeout in minutes'),
  ('max_active_loans',        '1',         'integer',  'Max concurrent active loans per lender'),
  ('due_reminder_days_before','2',         'integer',  'Days before due to send reminder'),
  ('gas_rate_per_km',         '15',        'decimal',  'Estimated gas cost per kilometer PHP');

-- ============================================================
-- TABLE: loan_products (loan tiers/templates)
-- ============================================================
CREATE TABLE loan_products (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_name     VARCHAR(150) NOT NULL,
  min_amount       DECIMAL(12,2) NOT NULL,
  max_amount       DECIMAL(12,2) NOT NULL,
  interest_rate    DECIMAL(5,2) NOT NULL,
  min_term_days    INT NOT NULL,
  max_term_days    INT NOT NULL,
  is_active        BOOLEAN NOT NULL DEFAULT TRUE,
  created_by       UUID REFERENCES users(id),
  is_archived      BOOLEAN NOT NULL DEFAULT FALSE,
  archived_at      TIMESTAMPTZ,
  archived_by      UUID REFERENCES users(id),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: loans
-- ============================================================
CREATE TABLE loans (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  loan_code             VARCHAR(50) NOT NULL UNIQUE,
  lender_id             UUID NOT NULL REFERENCES lenders(id),
  product_id            UUID REFERENCES loan_products(id),
  reviewed_by           UUID REFERENCES users(id),
  approved_by           UUID REFERENCES users(id),
  rejected_by           UUID REFERENCES users(id),
  principal_amount      DECIMAL(12,2) NOT NULL CHECK (principal_amount >= 5000 AND principal_amount <= 500000),
  interest_rate         DECIMAL(5,2) NOT NULL,
  total_interest        DECIMAL(12,2) NOT NULL,
  total_payable         DECIMAL(12,2) NOT NULL,
  processing_fee        DECIMAL(10,2) NOT NULL DEFAULT 0,
  service_fee           DECIMAL(10,2) NOT NULL DEFAULT 0,
  ci_fee                DECIMAL(10,2) NOT NULL DEFAULT 0,
  total_charges         DECIMAL(12,2) NOT NULL DEFAULT 0,
  net_disbursement      DECIMAL(12,2) NOT NULL,
  payment_frequency     payment_frequency_enum NOT NULL,
  term_days             INT NOT NULL,
  payment_amount        DECIMAL(12,2) NOT NULL,
  total_paid            DECIMAL(12,2) NOT NULL DEFAULT 0,
  total_penalties       DECIMAL(12,2) NOT NULL DEFAULT 0,
  outstanding_balance   DECIMAL(12,2) NOT NULL,
  loan_status           loan_status_enum NOT NULL DEFAULT 'pending',
  purpose               TEXT NOT NULL,
  remarks               TEXT,
  rejection_reason      TEXT,
  freeze_reason         TEXT,
  disbursed_at          TIMESTAMPTZ,
  due_start_at          TIMESTAMPTZ,
  expected_end_at       TIMESTAMPTZ,
  completed_at          TIMESTAMPTZ,
  is_archived           BOOLEAN NOT NULL DEFAULT FALSE,
  archived_at           TIMESTAMPTZ,
  archived_by           UUID REFERENCES users(id),
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: loan_schedules (payment schedule — 3NF atomic rows)
-- ============================================================
CREATE TABLE loan_schedules (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  loan_id         UUID NOT NULL REFERENCES loans(id) ON DELETE CASCADE,
  schedule_number INT NOT NULL,
  due_amount      DECIMAL(12,2) NOT NULL,
  penalty_amount  DECIMAL(12,2) NOT NULL DEFAULT 0,
  paid_amount     DECIMAL(12,2) NOT NULL DEFAULT 0,
  balance         DECIMAL(12,2) NOT NULL,
  due_date        TIMESTAMPTZ NOT NULL,
  paid_at         TIMESTAMPTZ,
  is_paid         BOOLEAN NOT NULL DEFAULT FALSE,
  is_overdue      BOOLEAN NOT NULL DEFAULT FALSE,
  overdue_since   TIMESTAMPTZ,
  grace_until     TIMESTAMPTZ,
  reminder_sent   BOOLEAN NOT NULL DEFAULT FALSE,
  reminder_sent_at TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(loan_id, schedule_number)
);

-- ============================================================
-- TABLE: loan_charges
-- ============================================================
CREATE TABLE loan_charges (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  loan_id      UUID NOT NULL REFERENCES loans(id) ON DELETE CASCADE,
  charge_type  charge_type_enum NOT NULL,
  amount       DECIMAL(10,2) NOT NULL CHECK (amount > 0),
  description  TEXT NOT NULL,
  added_by     UUID REFERENCES users(id),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: penalties
-- ============================================================
CREATE TABLE penalties (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  loan_id         UUID NOT NULL REFERENCES loans(id) ON DELETE CASCADE,
  schedule_id     UUID REFERENCES loan_schedules(id),
  penalty_type    VARCHAR(50) NOT NULL DEFAULT 'late_fee',
  amount          DECIMAL(10,2) NOT NULL CHECK (amount > 0),
  computed_days   INT NOT NULL DEFAULT 0,
  rate_applied    DECIMAL(5,2) NOT NULL,
  description     TEXT NOT NULL,
  is_waived       BOOLEAN NOT NULL DEFAULT FALSE,
  waived_by       UUID REFERENCES users(id),
  waived_at       TIMESTAMPTZ,
  waive_reason    TEXT,
  is_paid         BOOLEAN NOT NULL DEFAULT FALSE,
  paid_at         TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: payments
-- ============================================================
CREATE TABLE payments (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  payment_code        VARCHAR(50) NOT NULL UNIQUE,
  loan_id             UUID NOT NULL REFERENCES loans(id),
  schedule_id         UUID REFERENCES loan_schedules(id),
  lender_id           UUID NOT NULL REFERENCES lenders(id),
  collected_by        UUID REFERENCES riders(id),
  verified_by         UUID REFERENCES users(id),
  amount              DECIMAL(12,2) NOT NULL CHECK (amount > 0),
  penalty_covered     DECIMAL(10,2) NOT NULL DEFAULT 0,
  principal_covered   DECIMAL(12,2) NOT NULL DEFAULT 0,
  payment_method      payment_method_enum NOT NULL,
  payment_status      payment_status_enum NOT NULL DEFAULT 'pending',
  reference_number    VARCHAR(100),
  paymongo_payment_id VARCHAR(200),
  paymongo_source_id  VARCHAR(200),
  receipt_url         TEXT,
  proof_url           TEXT,
  signature_url       TEXT,
  remarks             TEXT,
  collected_at        TIMESTAMPTZ,
  processed_at        TIMESTAMPTZ,
  failed_reason       TEXT,
  is_archived         BOOLEAN NOT NULL DEFAULT FALSE,
  archived_at         TIMESTAMPTZ,
  archived_by         UUID REFERENCES users(id),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: paymongo_transactions
-- ============================================================
CREATE TABLE paymongo_transactions (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  payment_id          UUID NOT NULL REFERENCES payments(id),
  paymongo_id         VARCHAR(200) NOT NULL UNIQUE,
  transaction_type    VARCHAR(50) NOT NULL,
  amount_cents        BIGINT NOT NULL,
  currency            VARCHAR(10) NOT NULL DEFAULT 'PHP',
  status              VARCHAR(50) NOT NULL,
  payment_method_type payment_method_enum NOT NULL,
  source_type         VARCHAR(100),
  checkout_url        TEXT,
  return_url          TEXT,
  failure_code        VARCHAR(100),
  failure_message     TEXT,
  fee_amount_cents    BIGINT NOT NULL DEFAULT 0,
  net_amount_cents    BIGINT NOT NULL DEFAULT 0,
  metadata            JSONB,
  paid_at             TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: ci_assignments
-- ============================================================
CREATE TABLE ci_assignments (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  loan_id         UUID NOT NULL REFERENCES loans(id),
  rider_id        UUID NOT NULL REFERENCES riders(id),
  assigned_by     UUID NOT NULL REFERENCES users(id),
  reassigned_from UUID REFERENCES riders(id),
  ci_status       ci_status_enum NOT NULL DEFAULT 'pending',
  instructions    TEXT,
  priority_level  VARCHAR(20) NOT NULL DEFAULT 'normal',
  assigned_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  started_at      TIMESTAMPTZ,
  completed_at    TIMESTAMPTZ,
  reviewed_at     TIMESTAMPTZ,
  reviewed_by     UUID REFERENCES users(id),
  review_remarks  TEXT,
  is_archived     BOOLEAN NOT NULL DEFAULT FALSE,
  archived_at     TIMESTAMPTZ,
  archived_by     UUID REFERENCES users(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: ci_reports
-- ============================================================
CREATE TABLE ci_reports (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ci_assignment_id    UUID NOT NULL REFERENCES ci_assignments(id),
  rider_id            UUID NOT NULL REFERENCES riders(id),
  lender_id           UUID NOT NULL REFERENCES lenders(id),
  home_confirmed      BOOLEAN NOT NULL DEFAULT FALSE,
  business_confirmed  BOOLEAN NOT NULL DEFAULT FALSE,
  income_verified     BOOLEAN NOT NULL DEFAULT FALSE,
  neighbors_confirmed BOOLEAN NOT NULL DEFAULT FALSE,
  references_checked  BOOLEAN NOT NULL DEFAULT FALSE,
  recommendation      VARCHAR(50) NOT NULL DEFAULT 'pending',
  risk_assessment     VARCHAR(20) NOT NULL DEFAULT 'unrated',
  monthly_exp_est     DECIMAL(12,2),
  income_verified_amt DECIMAL(12,2),
  debt_to_income_ratio DECIMAL(5,2),
  remarks             TEXT NOT NULL,
  findings            TEXT NOT NULL,
  visit_latitude      DECIMAL(10,8),
  visit_longitude     DECIMAL(11,8),
  visit_address       TEXT,
  visit_duration_mins INT,
  submitted_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_archived         BOOLEAN NOT NULL DEFAULT FALSE,
  archived_at         TIMESTAMPTZ,
  archived_by         UUID REFERENCES users(id),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: ci_report_photos
-- ============================================================
CREATE TABLE ci_report_photos (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ci_report_id UUID NOT NULL REFERENCES ci_reports(id) ON DELETE CASCADE,
  photo_type   VARCHAR(100) NOT NULL,
  file_url     TEXT NOT NULL,
  file_name    VARCHAR(255) NOT NULL,
  file_size    BIGINT NOT NULL,
  mime_type    VARCHAR(100) NOT NULL,
  caption      TEXT,
  taken_at     TIMESTAMPTZ,
  latitude     DECIMAL(10,8),
  longitude    DECIMAL(11,8),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: collections
-- ============================================================
CREATE TABLE collections (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  collection_code   VARCHAR(50) NOT NULL UNIQUE,
  loan_id           UUID NOT NULL REFERENCES loans(id),
  schedule_id       UUID NOT NULL REFERENCES loan_schedules(id),
  lender_id         UUID NOT NULL REFERENCES lenders(id),
  rider_id          UUID REFERENCES riders(id),
  assigned_by       UUID REFERENCES users(id),
  collection_status collection_status_enum NOT NULL DEFAULT 'pending',
  target_amount     DECIMAL(12,2) NOT NULL,
  collected_amount  DECIMAL(12,2) NOT NULL DEFAULT 0,
  collection_notes  TEXT,
  failure_reason    TEXT,
  assigned_at       TIMESTAMPTZ,
  started_at        TIMESTAMPTZ,
  completed_at      TIMESTAMPTZ,
  is_archived       BOOLEAN NOT NULL DEFAULT FALSE,
  archived_at       TIMESTAMPTZ,
  archived_by       UUID REFERENCES users(id),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: collection_logs
-- ============================================================
CREATE TABLE collection_logs (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  collection_id  UUID NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
  log_event      VARCHAR(100) NOT NULL,
  description    TEXT NOT NULL,
  latitude       DECIMAL(10,8),
  longitude      DECIMAL(11,8),
  logged_by      UUID REFERENCES users(id),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: route_logs (GPS tracking for riders)
-- ============================================================
CREATE TABLE route_logs (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  rider_id     UUID NOT NULL REFERENCES riders(id),
  assignment_id UUID REFERENCES ci_assignments(id),
  collection_id UUID REFERENCES collections(id),
  latitude     DECIMAL(10,8) NOT NULL,
  longitude    DECIMAL(11,8) NOT NULL,
  speed_kmh    DECIMAL(6,2),
  accuracy_m   DECIMAL(8,2),
  recorded_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: gas_estimations
-- ============================================================
CREATE TABLE gas_estimations (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  rider_id        UUID NOT NULL REFERENCES riders(id),
  assignment_id   UUID REFERENCES ci_assignments(id),
  collection_id   UUID REFERENCES collections(id),
  origin_lat      DECIMAL(10,8) NOT NULL,
  origin_lng      DECIMAL(11,8) NOT NULL,
  dest_lat        DECIMAL(10,8) NOT NULL,
  dest_lng        DECIMAL(11,8) NOT NULL,
  distance_km     DECIMAL(8,2) NOT NULL,
  duration_mins   INT NOT NULL,
  estimated_gas   DECIMAL(8,2) NOT NULL,
  gas_rate_used   DECIMAL(8,2) NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: payment_receipts
-- ============================================================
CREATE TABLE payment_receipts (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  payment_id      UUID NOT NULL UNIQUE REFERENCES payments(id),
  receipt_number  VARCHAR(50) NOT NULL UNIQUE,
  receipt_url     TEXT NOT NULL,
  generated_by    UUID REFERENCES users(id),
  generated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  emailed_at      TIMESTAMPTZ,
  is_archived     BOOLEAN NOT NULL DEFAULT FALSE,
  archived_at     TIMESTAMPTZ,
  archived_by     UUID REFERENCES users(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: notifications
-- ============================================================
CREATE TABLE notifications (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  recipient_id      UUID NOT NULL REFERENCES users(id),
  sender_id         UUID REFERENCES users(id),
  notification_type notification_type_enum NOT NULL,
  title             VARCHAR(200) NOT NULL,
  body              TEXT NOT NULL,
  data              JSONB,
  is_read           BOOLEAN NOT NULL DEFAULT FALSE,
  read_at           TIMESTAMPTZ,
  fcm_message_id    TEXT,
  sent_via_push     BOOLEAN NOT NULL DEFAULT FALSE,
  push_sent_at      TIMESTAMPTZ,
  push_failed       BOOLEAN NOT NULL DEFAULT FALSE,
  push_fail_reason  TEXT,
  is_archived       BOOLEAN NOT NULL DEFAULT FALSE,
  archived_at       TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: sessions
-- ============================================================
CREATE TABLE sessions (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  session_token  TEXT NOT NULL UNIQUE,
  device_id      UUID,
  ip_address     INET,
  user_agent     TEXT,
  platform       VARCHAR(50),
  is_active      BOOLEAN NOT NULL DEFAULT TRUE,
  last_active_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at     TIMESTAMPTZ NOT NULL,
  invalidated_at TIMESTAMPTZ,
  invalidated_by UUID REFERENCES users(id),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: devices
-- ============================================================
CREATE TABLE devices (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_name  VARCHAR(200) NOT NULL,
  device_type  VARCHAR(50) NOT NULL,
  platform     VARCHAR(50) NOT NULL,
  os_version   VARCHAR(50),
  app_version  VARCHAR(50),
  fcm_token    TEXT,
  device_fingerprint TEXT,
  is_trusted   BOOLEAN NOT NULL DEFAULT FALSE,
  last_used_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: failed_login_attempts
-- ============================================================
CREATE TABLE failed_login_attempts (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email       VARCHAR(254) NOT NULL,
  ip_address  INET,
  user_agent  TEXT,
  reason      VARCHAR(200),
  attempted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: password_reset_logs
-- ============================================================
CREATE TABLE password_reset_logs (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       UUID NOT NULL REFERENCES users(id),
  reset_by      UUID REFERENCES users(id),
  reset_method  VARCHAR(50) NOT NULL DEFAULT 'admin_reset',
  ip_address    INET,
  is_used       BOOLEAN NOT NULL DEFAULT FALSE,
  expires_at    TIMESTAMPTZ NOT NULL,
  used_at       TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: audit_logs
-- ============================================================
CREATE TABLE audit_logs (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       UUID REFERENCES users(id),
  action        audit_action_enum NOT NULL,
  table_name    VARCHAR(100) NOT NULL,
  record_id     UUID,
  old_values    JSONB,
  new_values    JSONB,
  description   TEXT NOT NULL,
  ip_address    INET,
  user_agent    TEXT,
  session_id    UUID REFERENCES sessions(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: activity_logs
-- ============================================================
CREATE TABLE activity_logs (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES users(id),
  activity    VARCHAR(200) NOT NULL,
  module      VARCHAR(100) NOT NULL,
  description TEXT,
  metadata    JSONB,
  ip_address  INET,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: fraud_flags
-- ============================================================
CREATE TABLE fraud_flags (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id      UUID NOT NULL REFERENCES users(id),
  flag_type    VARCHAR(100) NOT NULL,
  severity     VARCHAR(20) NOT NULL DEFAULT 'medium',
  description  TEXT NOT NULL,
  metadata     JSONB,
  is_resolved  BOOLEAN NOT NULL DEFAULT FALSE,
  resolved_by  UUID REFERENCES users(id),
  resolved_at  TIMESTAMPTZ,
  resolution   TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: system_configs
-- ============================================================
CREATE TABLE system_configs (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  config_key   VARCHAR(100) NOT NULL UNIQUE,
  config_value TEXT NOT NULL,
  config_type  VARCHAR(50) NOT NULL DEFAULT 'string',
  description  TEXT,
  updated_by   UUID REFERENCES users(id),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO system_configs (config_key, config_value, config_type, description) VALUES
  ('company_name',    'Jireta Loans & Credit Corp. 1996', 'string', 'Company display name'),
  ('company_address', 'Sta. Barbara, Pangasinan',          'string', 'Company address'),
  ('company_phone',   '',                                  'string', 'Company contact number'),
  ('company_email',   '',                                  'string', 'Company email address'),
  ('maintenance_mode','false',                             'boolean','Enable maintenance mode'),
  ('app_version',     '1.0.0',                             'string', 'Current app version');

-- ============================================================
-- INDEXES
-- ============================================================

-- users indexes
CREATE INDEX idx_users_auth_id      ON users(auth_id);
CREATE INDEX idx_users_email        ON users USING gin(email gin_trgm_ops);
CREATE INDEX idx_users_role_id      ON users(role_id);
CREATE INDEX idx_users_status       ON users(account_status);
CREATE INDEX idx_users_archived     ON users(is_archived);
CREATE INDEX idx_users_phone        ON users(phone_number);
CREATE INDEX idx_users_last_name    ON users USING gin(last_name gin_trgm_ops);

-- loans indexes
CREATE INDEX idx_loans_lender       ON loans(lender_id);
CREATE INDEX idx_loans_status       ON loans(loan_status);
CREATE INDEX idx_loans_code         ON loans(loan_code);
CREATE INDEX idx_loans_archived     ON loans(is_archived);
CREATE INDEX idx_loans_created      ON loans(created_at DESC);

-- payments indexes
CREATE INDEX idx_payments_loan      ON payments(loan_id);
CREATE INDEX idx_payments_lender    ON payments(lender_id);
CREATE INDEX idx_payments_code      ON payments(payment_code);
CREATE INDEX idx_payments_status    ON payments(payment_status);
CREATE INDEX idx_payments_rider     ON payments(collected_by);

-- schedules indexes
CREATE INDEX idx_schedules_loan     ON loan_schedules(loan_id);
CREATE INDEX idx_schedules_due      ON loan_schedules(due_date);
CREATE INDEX idx_schedules_overdue  ON loan_schedules(is_overdue);
CREATE INDEX idx_schedules_paid     ON loan_schedules(is_paid);

-- collections indexes
CREATE INDEX idx_collections_loan   ON collections(loan_id);
CREATE INDEX idx_collections_rider  ON collections(rider_id);
CREATE INDEX idx_collections_status ON collections(collection_status);

-- ci_assignments indexes
CREATE INDEX idx_ci_assignment_loan  ON ci_assignments(loan_id);
CREATE INDEX idx_ci_assignment_rider ON ci_assignments(rider_id);
CREATE INDEX idx_ci_assignment_status ON ci_assignments(ci_status);

-- notifications indexes
CREATE INDEX idx_notif_recipient    ON notifications(recipient_id);
CREATE INDEX idx_notif_read         ON notifications(is_read);
CREATE INDEX idx_notif_type         ON notifications(notification_type);
CREATE INDEX idx_notif_created      ON notifications(created_at DESC);

-- audit_logs indexes
CREATE INDEX idx_audit_user         ON audit_logs(user_id);
CREATE INDEX idx_audit_table        ON audit_logs(table_name);
CREATE INDEX idx_audit_action       ON audit_logs(action);
CREATE INDEX idx_audit_created      ON audit_logs(created_at DESC);

-- route_logs indexes
CREATE INDEX idx_route_rider        ON route_logs(rider_id);
CREATE INDEX idx_route_recorded     ON route_logs(recorded_at DESC);

-- sessions indexes
CREATE INDEX idx_sessions_user      ON sessions(user_id);
CREATE INDEX idx_sessions_active    ON sessions(is_active);
CREATE INDEX idx_sessions_expires   ON sessions(expires_at);

-- lenders indexes
CREATE INDEX idx_lenders_user       ON lenders(user_id);
CREATE INDEX idx_lenders_code       ON lenders(lender_code);
CREATE INDEX idx_lenders_blacklisted ON lenders(is_blacklisted);

-- failed logins
CREATE INDEX idx_failed_login_email  ON failed_login_attempts(email);
CREATE INDEX idx_failed_login_time   ON failed_login_attempts(attempted_at DESC);
CREATE INDEX idx_failed_login_ip     ON failed_login_attempts(ip_address);

-- ============================================================
-- UPDATED_AT TRIGGER
-- ============================================================

CREATE OR REPLACE FUNCTION trigger_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to all tables with updated_at
DO $$
DECLARE
  t TEXT;
BEGIN
  FOR t IN SELECT unnest(ARRAY[
    'roles','permissions','role_permissions','users','addresses',
    'employees','riders','lenders','lender_documents','loan_settings',
    'loan_products','loans','loan_schedules','loan_charges','penalties',
    'payments','paymongo_transactions','ci_assignments','ci_reports',
    'collections','notifications','sessions','devices','fraud_flags',
    'system_configs','activity_logs'
  ])
  LOOP
    EXECUTE format('
      CREATE TRIGGER set_updated_at
      BEFORE UPDATE ON %I
      FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
    ', t);
  END LOOP;
END;
$$;

-- ============================================================
-- AUDIT LOG TRIGGER FUNCTION
-- ============================================================

CREATE OR REPLACE FUNCTION trigger_audit_log()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO audit_logs (user_id, action, table_name, record_id, new_values, description)
    VALUES (auth.uid(), 'create', TG_TABLE_NAME, NEW.id, row_to_json(NEW), 'Record created');
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO audit_logs (user_id, action, table_name, record_id, old_values, new_values, description)
    VALUES (auth.uid(), 'update', TG_TABLE_NAME, NEW.id, row_to_json(OLD), row_to_json(NEW), 'Record updated');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

ALTER TABLE users              ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees          ENABLE ROW LEVEL SECURITY;
ALTER TABLE riders             ENABLE ROW LEVEL SECURITY;
ALTER TABLE lenders            ENABLE ROW LEVEL SECURITY;
ALTER TABLE lender_documents   ENABLE ROW LEVEL SECURITY;
ALTER TABLE loans              ENABLE ROW LEVEL SECURITY;
ALTER TABLE loan_schedules     ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments           ENABLE ROW LEVEL SECURITY;
ALTER TABLE collections        ENABLE ROW LEVEL SECURITY;
ALTER TABLE ci_assignments     ENABLE ROW LEVEL SECURITY;
ALTER TABLE ci_reports         ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications      ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs         ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_logs      ENABLE ROW LEVEL SECURITY;
ALTER TABLE route_logs         ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions           ENABLE ROW LEVEL SECURITY;
ALTER TABLE devices            ENABLE ROW LEVEL SECURITY;
ALTER TABLE penalties          ENABLE ROW LEVEL SECURITY;
ALTER TABLE fraud_flags        ENABLE ROW LEVEL SECURITY;

-- Helper: get role name from auth.uid()
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS TEXT AS $$
  SELECT r.name::TEXT
  FROM users u
  JOIN roles r ON r.id = u.role_id
  WHERE u.auth_id = auth.uid()
$$ LANGUAGE SQL SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_user_id()
RETURNS UUID AS $$
  SELECT id FROM users WHERE auth_id = auth.uid()
$$ LANGUAGE SQL SECURITY DEFINER;

-- ============================================================
-- RLS POLICIES — users
-- ============================================================

CREATE POLICY "head_manager_full_users"
  ON users FOR ALL
  USING (get_user_role() = 'head_manager');

CREATE POLICY "employee_view_users"
  ON users FOR SELECT
  USING (get_user_role() = 'employee');

CREATE POLICY "rider_own_profile"
  ON users FOR SELECT
  USING (auth_id = auth.uid());

CREATE POLICY "lender_own_profile"
  ON users FOR SELECT
  USING (auth_id = auth.uid());

CREATE POLICY "users_update_own"
  ON users FOR UPDATE
  USING (auth_id = auth.uid())
  WITH CHECK (auth_id = auth.uid());

-- ============================================================
-- RLS POLICIES — loans
-- ============================================================

CREATE POLICY "head_manager_full_loans"
  ON loans FOR ALL
  USING (get_user_role() = 'head_manager');

CREATE POLICY "employee_manage_loans"
  ON loans FOR ALL
  USING (get_user_role() = 'employee');

CREATE POLICY "lender_own_loans"
  ON loans FOR SELECT
  USING (
    lender_id = (SELECT id FROM lenders WHERE user_id = get_user_id())
  );

CREATE POLICY "rider_assigned_loans"
  ON loans FOR SELECT
  USING (
    get_user_role() = 'rider' AND
    id IN (
      SELECT loan_id FROM ci_assignments
      WHERE rider_id = (SELECT id FROM riders WHERE user_id = get_user_id())
    )
  );

-- ============================================================
-- RLS POLICIES — notifications
-- ============================================================

CREATE POLICY "own_notifications"
  ON notifications FOR ALL
  USING (recipient_id = get_user_id());

CREATE POLICY "admin_all_notifications"
  ON notifications FOR ALL
  USING (get_user_role() = 'head_manager');

-- ============================================================
-- RLS POLICIES — payments
-- ============================================================

CREATE POLICY "head_manager_full_payments"
  ON payments FOR ALL
  USING (get_user_role() = 'head_manager');

CREATE POLICY "employee_view_payments"
  ON payments FOR SELECT
  USING (get_user_role() = 'employee');

CREATE POLICY "rider_own_collections"
  ON payments FOR SELECT
  USING (
    get_user_role() = 'rider' AND
    collected_by = (SELECT id FROM riders WHERE user_id = get_user_id())
  );

CREATE POLICY "lender_own_payments"
  ON payments FOR SELECT
  USING (
    lender_id = (SELECT id FROM lenders WHERE user_id = get_user_id())
  );

-- ============================================================
-- RLS POLICIES — ci_assignments
-- ============================================================

CREATE POLICY "head_manager_full_ci"
  ON ci_assignments FOR ALL
  USING (get_user_role() = 'head_manager');

CREATE POLICY "employee_manage_ci"
  ON ci_assignments FOR ALL
  USING (get_user_role() = 'employee');

CREATE POLICY "rider_own_ci"
  ON ci_assignments FOR SELECT
  USING (
    rider_id = (SELECT id FROM riders WHERE user_id = get_user_id())
  );

-- ============================================================
-- RLS POLICIES — audit_logs
-- ============================================================

CREATE POLICY "head_manager_audit_logs"
  ON audit_logs FOR SELECT
  USING (get_user_role() = 'head_manager');

CREATE POLICY "employee_own_audit"
  ON audit_logs FOR SELECT
  USING (user_id = get_user_id());

-- ============================================================
-- RLS POLICIES — sessions
-- ============================================================

CREATE POLICY "own_sessions"
  ON sessions FOR ALL
  USING (user_id = get_user_id());

CREATE POLICY "admin_all_sessions"
  ON sessions FOR ALL
  USING (get_user_role() = 'head_manager');

-- ============================================================
-- RLS POLICIES — route_logs
-- ============================================================

CREATE POLICY "rider_own_routes"
  ON route_logs FOR ALL
  USING (
    rider_id = (SELECT id FROM riders WHERE user_id = get_user_id())
  );

CREATE POLICY "manager_view_routes"
  ON route_logs FOR SELECT
  USING (get_user_role() IN ('head_manager', 'employee'));

-- ============================================================
-- RLS POLICIES — collections
-- ============================================================

CREATE POLICY "head_manager_full_collections"
  ON collections FOR ALL
  USING (get_user_role() = 'head_manager');

CREATE POLICY "employee_manage_collections"
  ON collections FOR ALL
  USING (get_user_role() = 'employee');

CREATE POLICY "rider_own_collections_table"
  ON collections FOR ALL
  USING (
    rider_id = (SELECT id FROM riders WHERE user_id = get_user_id())
  );

CREATE POLICY "lender_own_collections"
  ON collections FOR SELECT
  USING (
    lender_id = (SELECT id FROM lenders WHERE user_id = get_user_id())
  );

-- ============================================================
-- RLS POLICIES — lender_documents
-- ============================================================

CREATE POLICY "head_manager_full_docs"
  ON lender_documents FOR ALL
  USING (get_user_role() = 'head_manager');

CREATE POLICY "employee_view_docs"
  ON lender_documents FOR SELECT
  USING (get_user_role() = 'employee');

CREATE POLICY "lender_own_docs"
  ON lender_documents FOR ALL
  USING (
    lender_id = (SELECT id FROM lenders WHERE user_id = get_user_id())
  );

-- ============================================================
-- RLS POLICIES — penalties
-- ============================================================

CREATE POLICY "manager_full_penalties"
  ON penalties FOR ALL
  USING (get_user_role() IN ('head_manager', 'employee'));

CREATE POLICY "lender_view_penalties"
  ON penalties FOR SELECT
  USING (
    loan_id IN (
      SELECT id FROM loans WHERE lender_id = (
        SELECT id FROM lenders WHERE user_id = get_user_id()
      )
    )
  );

-- ============================================================
-- SEED DATA: Roles
-- ============================================================

INSERT INTO roles (name, display_name, description) VALUES
  ('head_manager', 'Head Manager',    'Full administrative access to all system features'),
  ('employee',     'Employee/Manager','Operational access for loan processing and management'),
  ('rider',        'Field Rider',     'Mobile access for CI and field collection operations'),
  ('lender',       'Borrower/Lender', 'Customer access for loan application and payments');

-- ============================================================
-- SEED DATA: Permissions
-- ============================================================

INSERT INTO permissions (code, name, module) VALUES
  -- User Management
  ('users.create',       'Create Users',          'users'),
  ('users.read',         'View Users',            'users'),
  ('users.update',       'Edit Users',            'users'),
  ('users.archive',      'Archive Users',         'users'),
  ('users.restore',      'Restore Users',         'users'),
  ('users.suspend',      'Suspend Users',         'users'),
  -- Loan Management
  ('loans.create',       'Create Loans',          'loans'),
  ('loans.read',         'View Loans',            'loans'),
  ('loans.update',       'Edit Loans',            'loans'),
  ('loans.approve',      'Approve Loans',         'loans'),
  ('loans.reject',       'Reject Loans',          'loans'),
  ('loans.archive',      'Archive Loans',         'loans'),
  ('loans.freeze',       'Freeze Loans',          'loans'),
  -- Payments
  ('payments.read',      'View Payments',         'payments'),
  ('payments.verify',    'Verify Payments',       'payments'),
  -- CI Operations
  ('ci.assign',          'Assign CI',             'ci'),
  ('ci.review',          'Review CI Reports',     'ci'),
  ('ci.approve',         'Approve CI',            'ci'),
  -- Collections
  ('collections.assign', 'Assign Collections',    'collections'),
  ('collections.read',   'View Collections',      'collections'),
  -- Reports
  ('reports.generate',   'Generate Reports',      'reports'),
  ('reports.export',     'Export Reports',        'reports'),
  -- Settings
  ('settings.manage',    'Manage System Settings','settings'),
  -- Audit
  ('audit.read',         'View Audit Logs',       'audit');

-- ============================================================
-- END OF SCHEMA
-- ============================================================