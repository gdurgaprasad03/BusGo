package com.example.busbooking.entity;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.LocalDateTime;

/** A one-time "forgot password" code. Only its BCrypt hash is stored. It expires and allows a few wrong guesses. */
@Entity
@Table(name = "password_reset_codes")
public class PasswordResetCode {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private Long userId;
    private String codeHash;
    private LocalDateTime expiresAt;
    private int attempts;
    private boolean used;
    private LocalDateTime createdAt;

    protected PasswordResetCode() {
    }

    public PasswordResetCode(Long userId, String codeHash, LocalDateTime expiresAt) {
        this.userId = userId;
        this.codeHash = codeHash;
        this.expiresAt = expiresAt;
        this.attempts = 0;
        this.used = false;
        this.createdAt = LocalDateTime.now();
    }

    public boolean isUsable(LocalDateTime now, int maxAttempts) {
        return !used && attempts < maxAttempts && now.isBefore(expiresAt);
    }

    public void recordWrongGuess() { attempts++; }
    public void markUsed() { used = true; }

    public Long getId() { return id; }
    public Long getUserId() { return userId; }
    public String getCodeHash() { return codeHash; }
    public LocalDateTime getExpiresAt() { return expiresAt; }
    public int getAttempts() { return attempts; }
    public boolean isUsed() { return used; }
    public LocalDateTime getCreatedAt() { return createdAt; }
}
