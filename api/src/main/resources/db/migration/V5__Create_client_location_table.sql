-- Client location tracking for ride coordination (airport pickups)
CREATE TABLE client_locations (
    ride_id UUID NOT NULL REFERENCES rides(id),
    client_id UUID NOT NULL REFERENCES persons(id),
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (ride_id)
);

CREATE INDEX idx_client_locations_client_id ON client_locations(client_id);
