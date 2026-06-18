-- DATEV-specific settings for the company: Steuerberater number, Mandant number,
-- and the Sachkontenlaenge (chart-of-accounts length). All three are optional.
-- When Sachkontenlänge is NULL the application defaults to 4.

ALTER TABLE company_settings
    ADD COLUMN IF NOT EXISTS datev_beraternummer    VARCHAR(7),
    ADD COLUMN IF NOT EXISTS datev_mandantennummer  VARCHAR(5),
    ADD COLUMN IF NOT EXISTS datev_sachkontenlaenge SMALLINT;
