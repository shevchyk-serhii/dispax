ALTER TABLE rides ADD COLUMN cancellation_reason VARCHAR(50);
ALTER TABLE rides ADD COLUMN cancellation_fee DECIMAL(10,2) DEFAULT 0;
ALTER TABLE rides ADD COLUMN cancelled_by UUID;
