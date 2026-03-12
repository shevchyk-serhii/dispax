-- FCM push notification tokens
CREATE TABLE IF NOT EXISTS fcm_tokens (
    person_id UUID NOT NULL REFERENCES persons(id),
    token TEXT NOT NULL UNIQUE,
    platform VARCHAR(20) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_fcm_tokens_person ON fcm_tokens(person_id);
