-- Pharma DB setup
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
