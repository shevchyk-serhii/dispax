-- Ride domain: pools, invoices, rides, and all ride-related child tables.
-- Depends on V1 (companies, persons), V2 (tariffs), V3 (schedule_days).
-- FK creation order within this file:
--   ride_pools, invoice_sequences, invoices (before rides — rides.invoice_id FK),
--   rides (folds V9 vehicle_class), sent_reminders, invoice_items,
--   client_locations, chat_messages, expenses, ride_templates, ride_ratings,
--   ride_pool_members, sent_checkpoint_notifications, eta_alerts, emergency_reassignments.
-- Folded in from later ALTERs:
--   V9: rides.vehicle_class VARCHAR(20) NOT NULL DEFAULT 'business'

-- ============================================================
-- Ride pools
-- ============================================================
CREATE TABLE ride_pools (
    id UUID PRIMARY KEY,
    company_id UUID NOT NULL,
    name VARCHAR(100),
    status VARCHAR(20) NOT NULL DEFAULT 'OPEN',
    driver_id UUID,
    max_passengers INT NOT NULL DEFAULT 4,
    current_passengers INT NOT NULL DEFAULT 0,
    route_direction VARCHAR(200),
    scheduled_time TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL
);

CREATE INDEX idx_ride_pools_company ON ride_pools(company_id);
CREATE INDEX idx_ride_pools_status ON ride_pools(status);

-- ============================================================
-- Invoice sequences
-- ============================================================
CREATE TABLE invoice_sequences (
    company_id UUID PRIMARY KEY REFERENCES companies(id),
    last_number INTEGER NOT NULL DEFAULT 0
);

-- ============================================================
-- Client companies invoices
-- ============================================================
CREATE TABLE invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    number VARCHAR(50) NOT NULL,
    client_company_id UUID NOT NULL REFERENCES client_companies(id),
    taxi_company_id UUID NOT NULL REFERENCES companies(id),
    status VARCHAR(20) NOT NULL DEFAULT 'draft',
    period_from DATE NOT NULL,
    period_to DATE NOT NULL,
    subtotal_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    tax_rate DECIMAL(5,2) NOT NULL DEFAULT 0,
    tax_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    currency VARCHAR(3) NOT NULL DEFAULT 'EUR',
    notes TEXT,
    due_date DATE,
    sent_at TIMESTAMP WITH TIME ZONE,
    paid_at TIMESTAMP WITH TIME ZONE,
    -- When an overdue-payment reminder was sent, so the background scheduler
    -- emails each unpaid invoice at most once.
    reminder_sent_at TIMESTAMP WITH TIME ZONE,
    pdf_path TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE (number, taxi_company_id)
);

CREATE INDEX idx_invoices_taxi_company ON invoices(taxi_company_id);
CREATE INDEX idx_invoices_client_company ON invoices(client_company_id);
CREATE INDEX idx_invoices_status ON invoices(status);
CREATE INDEX idx_invoices_period ON invoices(period_from, period_to);

-- Supports the scheduler's candidate query (sent + unpaid + overdue + not yet reminded).
CREATE INDEX idx_invoices_overdue
    ON invoices (due_date)
    WHERE status = 'sent' AND paid_at IS NULL AND reminder_sent_at IS NULL;

-- ============================================================
-- Rides
-- ============================================================
-- Folded in: V9 vehicle_class VARCHAR(20) NOT NULL DEFAULT 'business'
CREATE TABLE rides (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID NOT NULL REFERENCES persons(id),
    creator_id UUID NOT NULL REFERENCES persons(id),
    driver_id UUID REFERENCES persons(id),
    company_id UUID NOT NULL REFERENCES companies(id),
    invoice_id UUID REFERENCES invoices(id) ON DELETE SET NULL,

    from_address VARCHAR(500) NOT NULL,
    from_lat DOUBLE PRECISION,
    from_lng DOUBLE PRECISION,
    to_address VARCHAR(500) NOT NULL,
    to_lat DOUBLE PRECISION,
    to_lng DOUBLE PRECISION,

    pickup_datetime TIMESTAMP WITH TIME ZONE NOT NULL,
    scheduled_time TIMESTAMP WITH TIME ZONE,
    request_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    start_time TIMESTAMP WITH TIME ZONE,
    end_time TIMESTAMP WITH TIME ZONE,

    status ride_status NOT NULL DEFAULT 'Requested',
    tariff_id UUID REFERENCES tariffs(company_id),
    estimated_price_amount DECIMAL(10,2),
    estimated_price_currency VARCHAR(3) DEFAULT 'EUR',
    final_price_amount DECIMAL(10,2),
    final_price_currency VARCHAR(3) DEFAULT 'EUR',
    price_amount DECIMAL(10,2),
    price_currency VARCHAR(3),
    estimated_distance_km DOUBLE PRECISION,

    flight_number VARCHAR(20),
    flight_time TIMESTAMP WITH TIME ZONE,
    flight_gate VARCHAR(10),
    flight_terminal VARCHAR(10),
    flight_status VARCHAR(50),
    flight_is_arrival BOOLEAN,
    -- Current airport checkpoint for arrival-transfer rides: landed | arrivals_hall | terminal_exit
    airport_checkpoint VARCHAR(30) DEFAULT NULL,
    specifics JSONB,

    -- V9: stored as a plain string (not a PG enum) to match how AirportCheckpoint is
    -- persisted and to avoid an enum-alter migration when classes change.
    vehicle_class VARCHAR(20) NOT NULL DEFAULT 'business',

    schedule_day_id UUID REFERENCES schedule_days(id),

    notes TEXT,
    special_requirements TEXT,

    payment_status payment_status NOT NULL DEFAULT 'Unpaid',
    payment_method payment_method,
    paid_at TIMESTAMP WITH TIME ZONE,

    cancellation_reason VARCHAR(50),
    cancellation_fee DECIMAL(10,2) DEFAULT 0,
    cancelled_by UUID,

    is_vip_ride BOOLEAN DEFAULT FALSE,
    preferred_driver_used BOOLEAN DEFAULT FALSE,

    pool_id UUID REFERENCES ride_pools(id),

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_rides_client_id ON rides(client_id);
CREATE INDEX idx_rides_driver_id ON rides(driver_id);
CREATE INDEX idx_rides_company_id ON rides(company_id);
CREATE INDEX idx_rides_status ON rides(status);
CREATE INDEX idx_rides_pickup_datetime ON rides(pickup_datetime);
CREATE INDEX idx_rides_scheduled_time ON rides(scheduled_time);
CREATE INDEX idx_rides_request_time ON rides(request_time);
CREATE INDEX idx_rides_specifics ON rides USING gin(specifics);
CREATE INDEX idx_rides_specifics_type ON rides ((specifics->>'type'));
CREATE INDEX idx_rides_schedule_day_id ON rides(schedule_day_id);
CREATE INDEX idx_rides_invoice_id ON rides(invoice_id);

-- ============================================================
-- Sent reminders (deduplication of ride push reminders)
-- ============================================================
CREATE TABLE sent_reminders (
    ride_id   UUID        NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
    person_id UUID        NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
    sent_at   TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    PRIMARY KEY (ride_id, person_id)
);

-- ============================================================
-- Invoice items
-- ============================================================
CREATE TABLE invoice_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    ride_id UUID REFERENCES rides(id) ON DELETE SET NULL,
    description TEXT NOT NULL,
    quantity DECIMAL(10,2) NOT NULL DEFAULT 1,
    unit_price DECIMAL(10,2) NOT NULL,
    total DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_invoice_items_invoice ON invoice_items(invoice_id);
CREATE INDEX idx_invoice_items_ride ON invoice_items(ride_id);

-- ============================================================
-- Client locations
-- ============================================================
CREATE TABLE client_locations (
    ride_id UUID NOT NULL REFERENCES rides(id),
    client_id UUID NOT NULL REFERENCES persons(id),
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (ride_id)
);

CREATE INDEX idx_client_locations_client_id ON client_locations(client_id);

-- ============================================================
-- Chat messages
-- ============================================================
CREATE TABLE chat_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ride_id UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES persons(id),
    message TEXT NOT NULL,
    sent_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_chat_messages_ride_id ON chat_messages(ride_id);
CREATE INDEX idx_chat_messages_sent_at ON chat_messages(sent_at);

-- ============================================================
-- Expenses
-- ============================================================
CREATE TABLE expenses (
    id UUID PRIMARY KEY,
    ride_id UUID REFERENCES rides(id),
    driver_id UUID NOT NULL REFERENCES persons(id),
    company_id UUID NOT NULL REFERENCES companies(id),
    category VARCHAR(50) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'EUR',
    description TEXT,
    receipt_url TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_expenses_ride_id ON expenses(ride_id);
CREATE INDEX idx_expenses_driver_id ON expenses(driver_id);
CREATE INDEX idx_expenses_company_id ON expenses(company_id);

-- ============================================================
-- Ride templates
-- ============================================================
CREATE TABLE ride_templates (
    id UUID PRIMARY KEY,
    company_id UUID NOT NULL REFERENCES companies(id),
    client_id UUID NOT NULL REFERENCES persons(id),
    creator_id UUID NOT NULL REFERENCES persons(id),
    name VARCHAR(255) NOT NULL,
    from_address VARCHAR(500) NOT NULL,
    from_lat DOUBLE PRECISION,
    from_lng DOUBLE PRECISION,
    to_address VARCHAR(500) NOT NULL,
    to_lat DOUBLE PRECISION,
    to_lng DOUBLE PRECISION,
    preferred_driver_id UUID REFERENCES persons(id),
    notes TEXT,
    recurrence_pattern VARCHAR(50) NOT NULL,
    recurrence_days VARCHAR(50),
    pickup_time TIME NOT NULL,
    is_active BOOLEAN DEFAULT true,
    flight_number VARCHAR(20),
    is_airport_transfer BOOLEAN DEFAULT false,
    price DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_ride_templates_company ON ride_templates(company_id);
CREATE INDEX idx_ride_templates_client ON ride_templates(client_id);

-- ============================================================
-- Ride ratings
-- ============================================================
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

-- ============================================================
-- Ride pool members
-- ============================================================
CREATE TABLE ride_pool_members (
    id UUID PRIMARY KEY,
    pool_id UUID NOT NULL REFERENCES ride_pools(id),
    ride_id UUID NOT NULL,
    client_id UUID NOT NULL,
    pickup_order INT NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    added_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ride_pool_members_pool ON ride_pool_members(pool_id);
CREATE INDEX idx_ride_pool_members_ride ON ride_pool_members(ride_id);

-- ============================================================
-- Airport checkpoint push notification deduplication
-- ============================================================
CREATE TABLE sent_checkpoint_notifications (
    ride_id         UUID         NOT NULL REFERENCES rides(id)   ON DELETE CASCADE,
    driver_id       UUID         NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
    checkpoint_type VARCHAR(50)  NOT NULL,
    sent_at         TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    PRIMARY KEY (ride_id, driver_id, checkpoint_type)
);

CREATE INDEX idx_sent_checkpoint_ride ON sent_checkpoint_notifications(ride_id);

-- ============================================================
-- ETA-at-risk alert deduplication (predictive ETA monitor)
-- ============================================================
-- One row per (ride, driver) once a delay-risk alert has been sent, so the
-- background monitor does not re-alert the dispatcher every tick. Mirrors
-- sent_reminders. Cleared when the ride's pickup time changes.
CREATE TABLE eta_alerts (
    ride_id    UUID        NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
    driver_id  UUID        NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
    alerted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    PRIMARY KEY (ride_id, driver_id)
);

-- ============================================================
-- Emergency reassignments
-- ============================================================
CREATE TABLE emergency_reassignments (
    id UUID PRIMARY KEY,
    ride_id UUID NOT NULL REFERENCES rides(id),
    company_id UUID NOT NULL REFERENCES companies(id),
    original_driver_id UUID NOT NULL REFERENCES persons(id),
    new_driver_id UUID REFERENCES persons(id),
    reason VARCHAR(50) NOT NULL,
    notes TEXT,
    reassigned_by UUID NOT NULL REFERENCES persons(id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING'
);

CREATE INDEX idx_emergency_reassign_ride ON emergency_reassignments(ride_id);
CREATE INDEX idx_emergency_reassign_company ON emergency_reassignments(company_id);
