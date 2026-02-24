-- Pharma DB setup

-- ============================================================
-- Core pharmacy domain tables
-- ============================================================

CREATE TABLE IF NOT EXISTS pharmacy (
    id       SERIAL PRIMARY KEY,
    name     VARCHAR(255) NOT NULL,
    address  VARCHAR(500) NOT NULL,
    city     VARCHAR(100) NOT NULL DEFAULT 'Sofia'
);

CREATE TABLE IF NOT EXISTS medication (
    id            SERIAL PRIMARY KEY,
    name          VARCHAR(255) NOT NULL,
    generic_name  VARCHAR(255) NOT NULL,
    price_eur     DECIMAL(10, 2) NOT NULL
);

-- Per-pharmacy stock levels (pharmacy × medication → stock_level)
CREATE TABLE IF NOT EXISTS medication_stock (
    pharmacy_id    INT NOT NULL REFERENCES pharmacy(id),
    medication_id  INT NOT NULL REFERENCES medication(id),
    stock_level    INT NOT NULL DEFAULT 0,
    last_synced_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (pharmacy_id, medication_id)
);

CREATE TABLE IF NOT EXISTS reservation (
    id              SERIAL PRIMARY KEY,
    pharmacy_id     INT NOT NULL REFERENCES pharmacy(id),
    medication_id   INT NOT NULL REFERENCES medication(id),
    patient_nhif_id VARCHAR(50) NOT NULL,
    timestamp       TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    status          VARCHAR(20) NOT NULL DEFAULT 'Pending',
    CONSTRAINT reservation_status_chk CHECK (status IN ('Pending', 'Ready', 'PickedUp'))
);

CREATE TABLE IF NOT EXISTS prescription (
    id              SERIAL PRIMARY KEY,
    patient_nhif_id VARCHAR(50) NOT NULL,
    medication_id   INT NOT NULL REFERENCES medication(id),
    issued_by       VARCHAR(255) NOT NULL,
    issued_at       TIMESTAMP WITH TIME ZONE NOT NULL,
    valid_until     TIMESTAMP WITH TIME ZONE NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'Active',
    CONSTRAINT prescription_status_chk CHECK (status IN ('Active', 'Used', 'Expired'))
);

CREATE TABLE IF NOT EXISTS shortage_broadcast (
    id               SERIAL PRIMARY KEY,
    from_pharmacy_id INT NOT NULL REFERENCES pharmacy(id),
    medication_id    INT NOT NULL REFERENCES medication(id),
    quantity_needed  INT NOT NULL,
    broadcast_at     TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    resolved         BOOLEAN NOT NULL DEFAULT false
);

-- ============================================================
-- 5 Sofia pilot pharmacies
-- ============================================================

INSERT INTO pharmacy (name, address, city) VALUES
    ('Аптека Централна',  'бул. Витоша 1, ет. 1',           'Sofia'),
    ('Аптека Люлин',      'бул. Луи Айер 11',               'Sofia'),
    ('Аптека Надежда',    'ул. Илиянци 32',                  'Sofia'),
    ('Аптека Младост',    'бул. Александър Малинов 51',      'Sofia'),
    ('Аптека Студентска', 'бул. Климент Охридски 8', 'Sofia');

-- ============================================================
-- 10 common medications
-- ============================================================

INSERT INTO medication (name, generic_name, price_eur) VALUES
    ('Аспирин 500 мг',     'acetylsalicylic acid',  2.50),
    ('Парацетамол 500 мг', 'paracetamol',           1.80),
    ('Ибупрофен 400 мг',   'ibuprofen',             3.20),
    ('Амоксицилин 500 мг', 'amoxicillin',           8.90),
    ('Омепразол 20 мг',    'omeprazole',            5.40),
    ('Метформин 850 мг',   'metformin',             4.10),
    ('Лозартан 50 мг',     'losartan',              6.70),
    ('Аторвастатин 20 мг', 'atorvastatin',          9.30),
    ('Цетиризин 10 мг',    'cetirizine',            3.60),
    ('Пантопразол 40 мг',  'pantoprazole',          7.20);

-- ============================================================
-- Per-pharmacy stock levels (5 pharmacies × 10 medications)
-- ============================================================

INSERT INTO medication_stock (pharmacy_id, medication_id, stock_level) VALUES
    -- Pharmacy 1 (Централна) – well stocked
    (1, 1, 120), (1, 2, 95), (1, 3, 80), (1, 4, 45), (1, 5, 60),
    (1, 6, 30),  (1, 7, 50), (1, 8, 25), (1, 9, 70), (1, 10, 40),
    -- Pharmacy 2 (Люлин) – moderate stock
    (2, 1, 60),  (2, 2, 40), (2, 3, 35), (2, 4, 10), (2, 5, 20),
    (2, 6, 15),  (2, 7, 22), (2, 8, 8),  (2, 9, 45), (2, 10, 18),
    -- Pharmacy 3 (Надежда) – low stock on several items
    (3, 1, 30),  (3, 2, 55), (3, 3, 5),  (3, 4, 0),  (3, 5, 12),
    (3, 6, 40),  (3, 7, 0),  (3, 8, 33), (3, 9, 18), (3, 10, 9),
    -- Pharmacy 4 (Младост) – average
    (4, 1, 75),  (4, 2, 60), (4, 3, 50), (4, 4, 20), (4, 5, 35),
    (4, 6, 25),  (4, 7, 18), (4, 8, 42), (4, 9, 55), (4, 10, 30),
    -- Pharmacy 5 (Студентска) – high demand area
    (5, 1, 200), (5, 2, 150),(5, 3, 90), (5, 4, 55), (5, 5, 80),
    (5, 6, 60),  (5, 7, 70), (5, 8, 35), (5, 9, 110),(5, 10, 65);

-- ============================================================
-- Sample prescriptions (2 active/valid, 1 expired) for testing
-- ============================================================

INSERT INTO prescription (patient_nhif_id, medication_id, issued_by, issued_at, valid_until, status) VALUES
    -- BG-001-2025: valid prescription for Amoxicillin (med id 4) – use in validate tests
    ('BG-001-2025', 4, 'Д-р Иванова Мария', NOW() - INTERVAL '3 days', NOW() + INTERVAL '27 days', 'Active'),
    -- BG-002-2025: valid prescription for Metformin (med id 6)
    ('BG-002-2025', 6, 'Д-р Петров Георги', NOW() - INTERVAL '1 day',  NOW() + INTERVAL '29 days', 'Active'),
    -- BG-999-2024: EXPIRED prescription for Ibuprofen (med id 3) – use to test rejection
    ('BG-999-2024', 3, 'Д-р Димитров Стоян', NOW() - INTERVAL '60 days', NOW() - INTERVAL '30 days', 'Active');

-- ============================================================
-- Sample shortage broadcast (pharmacy 3 is out of Amoxicillin)
-- ============================================================

INSERT INTO shortage_broadcast (from_pharmacy_id, medication_id, quantity_needed, resolved) VALUES
    (3, 4, 15, false);

-- ============================================================
-- Legacy 'today' table (kept for backwards compatibility)
-- ============================================================

CREATE TABLE IF NOT EXISTS today (
    id              SERIAL PRIMARY KEY,
    title           VARCHAR(255) NOT NULL,
    content         TEXT,
    value           DECIMAL(10, 2),
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO today (title, content, value) VALUES
    ('Morning Report', 'Initial system check completed successfully.', 100.50),
    ('Inventory Update', 'Stock levels adjusted for Q1 medications.', 2500.00),
    ('Patient Summary', 'Daily patient intake: 45 new registrations.', 45.00),
    ('Lab Results', 'Pending lab analyses: 12 samples awaiting processing.', 12.00),
    ('Evening Summary', 'All systems operational. Ready for next day.', 999.99);
