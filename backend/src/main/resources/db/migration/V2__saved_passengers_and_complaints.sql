-- Saved passengers (reusable traveller details) and support complaints.

CREATE TABLE saved_passengers (
    id         BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id    BIGINT       NOT NULL,
    name       VARCHAR(100) NOT NULL,
    age        INT          NOT NULL,
    gender     VARCHAR(10)  NOT NULL,
    created_at DATETIME     NOT NULL,
    CONSTRAINT fk_saved_passengers_user FOREIGN KEY (user_id) REFERENCES users (id)
);
CREATE INDEX idx_saved_passengers_user ON saved_passengers (user_id);

CREATE TABLE complaints (
    id                BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id           BIGINT        NOT NULL,
    booking_reference VARCHAR(20)   NULL,
    subject           VARCHAR(120)  NOT NULL,
    message           VARCHAR(1000) NOT NULL,
    status            VARCHAR(12)   NOT NULL,
    created_at        DATETIME      NOT NULL,
    CONSTRAINT fk_complaints_user FOREIGN KEY (user_id) REFERENCES users (id)
);
CREATE INDEX idx_complaints_user ON complaints (user_id, created_at);
