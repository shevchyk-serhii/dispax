-- Настройка напоминания водителя: за сколько минут до поездки отправлять push
ALTER TABLE persons ADD COLUMN reminder_minutes INTEGER NOT NULL DEFAULT 60;

-- Дедупликация: чтобы не отправлять одно напоминание дважды
CREATE TABLE sent_reminders (
    ride_id   UUID        NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
    person_id UUID        NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
    sent_at   TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    PRIMARY KEY (ride_id, person_id)
);
