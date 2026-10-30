-- BusGo schema. Written to work on both MySQL 8 and H2 (MySQL mode, used by tests).

CREATE TABLE users (
    id            BIGINT AUTO_INCREMENT PRIMARY KEY,
    full_name     VARCHAR(100) NOT NULL,
    email         VARCHAR(150) NOT NULL,
    phone         VARCHAR(15)  NOT NULL,
    password_hash VARCHAR(100) NOT NULL,
    created_at    DATETIME     NOT NULL,
    CONSTRAINT uq_users_email UNIQUE (email)
);

CREATE TABLE operators (
    id     BIGINT AUTO_INCREMENT PRIMARY KEY,
    name   VARCHAR(100) NOT NULL,
    rating DECIMAL(2,1) NOT NULL,
    CONSTRAINT uq_operators_name UNIQUE (name)
);

-- A physical vehicle owned by an operator.
CREATE TABLE buses (
    id                  BIGINT AUTO_INCREMENT PRIMARY KEY,
    operator_id         BIGINT      NOT NULL,
    registration_number VARCHAR(30) NOT NULL,
    bus_type            VARCHAR(20) NOT NULL,
    total_seats         INT         NOT NULL,
    CONSTRAINT uq_buses_registration UNIQUE (registration_number),
    CONSTRAINT fk_buses_operator FOREIGN KEY (operator_id) REFERENCES operators (id)
);

-- A scheduled journey of a bus on a specific date/time.
CREATE TABLE trips (
    id             BIGINT AUTO_INCREMENT PRIMARY KEY,
    bus_id         BIGINT        NOT NULL,
    source         VARCHAR(60)   NOT NULL,
    destination    VARCHAR(60)   NOT NULL,
    departure_time DATETIME      NOT NULL,
    arrival_time   DATETIME      NOT NULL,
    fare           DECIMAL(10,2) NOT NULL,
    boarding_point VARCHAR(120)  NOT NULL,
    dropping_point VARCHAR(120)  NOT NULL,
    CONSTRAINT uq_trips_bus_departure UNIQUE (bus_id, departure_time),
    CONSTRAINT fk_trips_bus FOREIGN KEY (bus_id) REFERENCES buses (id)
);
CREATE INDEX idx_trips_search ON trips (source, destination, departure_time);

-- Seat inventory: one row per seat PER TRIP.
CREATE TABLE trip_seats (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    trip_id     BIGINT      NOT NULL,
    seat_number VARCHAR(10) NOT NULL,
    deck        VARCHAR(10) NOT NULL,
    seat_row    INT         NOT NULL,
    seat_col    INT         NOT NULL,
    status      VARCHAR(10) NOT NULL,
    CONSTRAINT uq_trip_seat UNIQUE (trip_id, seat_number),
    CONSTRAINT fk_trip_seats_trip FOREIGN KEY (trip_id) REFERENCES trips (id)
);

CREATE TABLE bookings (
    id             BIGINT AUTO_INCREMENT PRIMARY KEY,
    reference      VARCHAR(20)   NOT NULL,
    user_id        BIGINT        NOT NULL,
    trip_id        BIGINT        NOT NULL,
    status         VARCHAR(12)   NOT NULL,
    total_amount   DECIMAL(10,2) NOT NULL,
    refund_amount  DECIMAL(10,2) NULL,
    contact_phone  VARCHAR(15)   NOT NULL,
    contact_email  VARCHAR(150)  NOT NULL,
    payment_method VARCHAR(20)   NOT NULL,
    created_at     DATETIME      NOT NULL,
    cancelled_at   DATETIME      NULL,
    CONSTRAINT uq_bookings_reference UNIQUE (reference),
    CONSTRAINT fk_bookings_user FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT fk_bookings_trip FOREIGN KEY (trip_id) REFERENCES trips (id)
);
CREATE INDEX idx_bookings_user ON bookings (user_id, created_at);

-- Links a booking to the trip seats it holds, plus the passenger sitting there.
-- active_trip_seat_id is set while the booking is CONFIRMED and set to NULL on cancellation.
-- Its UNIQUE constraint is the database-level guarantee that a trip seat can never be
-- held by two confirmed bookings (NULLs are ignored by UNIQUE, so cancelled rows are fine).
CREATE TABLE booking_seats (
    id                  BIGINT AUTO_INCREMENT PRIMARY KEY,
    booking_id          BIGINT       NOT NULL,
    trip_seat_id        BIGINT       NOT NULL,
    active_trip_seat_id BIGINT       NULL,
    passenger_name      VARCHAR(100) NOT NULL,
    passenger_age       INT          NOT NULL,
    passenger_gender    VARCHAR(10)  NOT NULL,
    CONSTRAINT uq_booking_seats_active UNIQUE (active_trip_seat_id),
    CONSTRAINT fk_booking_seats_booking FOREIGN KEY (booking_id) REFERENCES bookings (id),
    CONSTRAINT fk_booking_seats_seat FOREIGN KEY (trip_seat_id) REFERENCES trip_seats (id)
);
