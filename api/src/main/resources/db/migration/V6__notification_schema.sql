-- Notification infrastructure: push notifications, preferences, and FCM tokens.
-- Depends on V1 (companies, persons).

-- ============================================================
-- Notifications
-- ============================================================
CREATE TABLE notifications (
    id UUID PRIMARY KEY,
    person_id UUID NOT NULL REFERENCES persons(id),
    company_id UUID NOT NULL REFERENCES companies(id),
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    type VARCHAR(50) NOT NULL,
    data JSONB,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_notifications_person ON notifications(person_id);
CREATE INDEX idx_notifications_company ON notifications(company_id);
CREATE INDEX idx_notifications_created ON notifications(created_at DESC);

-- ============================================================
-- Notification preferences
-- ============================================================
CREATE TABLE notification_preferences (
    id UUID PRIMARY KEY,
    person_id UUID NOT NULL UNIQUE,
    ride_updates BOOLEAN NOT NULL DEFAULT TRUE,
    chat_messages BOOLEAN NOT NULL DEFAULT TRUE,
    driver_approaching BOOLEAN NOT NULL DEFAULT TRUE,
    geofence_alerts BOOLEAN NOT NULL DEFAULT TRUE,
    pool_updates BOOLEAN NOT NULL DEFAULT TRUE,
    email_notifications BOOLEAN NOT NULL DEFAULT FALSE,
    sms_notifications BOOLEAN NOT NULL DEFAULT FALSE,
    quiet_hours_start TIME,
    quiet_hours_end TIME,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notification_prefs_person ON notification_preferences(person_id);

-- ============================================================
-- FCM tokens
-- ============================================================
CREATE TABLE fcm_tokens (
    person_id UUID NOT NULL REFERENCES persons(id),
    token TEXT NOT NULL UNIQUE,
    platform VARCHAR(20) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_fcm_tokens_person ON fcm_tokens(person_id);
