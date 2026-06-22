-- Airport pickup timing overrides for departure rides.
-- NULL at company level means "use global default from AirportPickupConfig".
-- NULL at client level means "use company (or global) default".

ALTER TABLE company_settings
  ADD COLUMN airport_buffer_minutes       INTEGER,
  ADD COLUMN airport_checkin_close_minutes INTEGER;

ALTER TABLE client_companies
  ADD COLUMN airport_buffer_minutes        INTEGER,
  ADD COLUMN airport_checkin_close_minutes INTEGER;
