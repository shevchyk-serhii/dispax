CREATE TABLE ride_ratings (
    id UUID PRIMARY KEY,
    ride_id UUID NOT NULL REFERENCES rides(id),
    client_id UUID NOT NULL REFERENCES persons(id),
    driver_id UUID NOT NULL REFERENCES persons(id),
    company_id UUID NOT NULL REFERENCES companies(id),
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);
CREATE UNIQUE INDEX idx_ride_ratings_ride ON ride_ratings(ride_id);
CREATE INDEX idx_ride_ratings_driver ON ride_ratings(driver_id);
