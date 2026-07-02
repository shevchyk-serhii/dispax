-- Provisional ("walk-in / from-chat") clients.
-- A provisional Person is a lightweight client created on the fly to book a ride when no real
-- client is known yet (e.g. a job taken from a chat: only route/price/payment/flight). It does not
-- log in (synthetic email, placeholder password) and is upgraded in place into a real client later.
-- Excluded from billing until upgraded.
ALTER TABLE persons ADD COLUMN provisional BOOLEAN NOT NULL DEFAULT FALSE;
