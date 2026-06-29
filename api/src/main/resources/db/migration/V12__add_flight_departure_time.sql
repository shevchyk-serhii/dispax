-- Origin take-off instant for airport ARRIVAL rides.
-- Scraped from the flight's MUC detail page (departure block). Lets the driver card animate the
-- en-route progress as (now - flight_departure_time) / (flight_time - flight_departure_time):
-- the airplane icon crawls toward "Gelandet" as the arrival approaches. Null until the flight
-- monitor has fetched detail data, or for non-arrival rides.
ALTER TABLE rides ADD COLUMN flight_departure_time TIMESTAMP WITH TIME ZONE;
