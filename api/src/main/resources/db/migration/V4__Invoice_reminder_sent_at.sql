-- Track when an overdue-payment reminder was sent, so the background scheduler
-- emails each unpaid invoice at most once.
ALTER TABLE invoices ADD COLUMN reminder_sent_at TIMESTAMP WITH TIME ZONE;

-- Supports the scheduler's candidate query (sent + unpaid + overdue + not yet reminded).
CREATE INDEX idx_invoices_overdue
    ON invoices (due_date)
    WHERE status = 'sent' AND paid_at IS NULL AND reminder_sent_at IS NULL;
