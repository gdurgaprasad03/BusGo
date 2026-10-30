-- One-time codes for "forgot password". Only a BCrypt hash of the 6-digit code is stored (never the code itself).
CREATE TABLE password_reset_codes (
    id         BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id    BIGINT       NOT NULL,
    code_hash  VARCHAR(100) NOT NULL,
    expires_at DATETIME     NOT NULL,
    attempts   INT          NOT NULL,
    used       BOOLEAN      NOT NULL,
    created_at DATETIME     NOT NULL,
    CONSTRAINT fk_reset_codes_user FOREIGN KEY (user_id) REFERENCES users (id)
);
CREATE INDEX idx_reset_codes_user ON password_reset_codes (user_id, created_at);
