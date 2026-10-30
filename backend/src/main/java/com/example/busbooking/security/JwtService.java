package com.example.busbooking.security;

import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Date;
import java.util.Optional;

/**
 * Creates and verifies JWT login tokens (HS256).
 * The token's subject is the user id. The signing secret comes from configuration, never from code.
 */
@Service
public class JwtService {

    private final SecretKey key;
    private final Duration lifetime;

    public JwtService(@Value("${app.jwt.secret:}") String secret,
                      @Value("${app.jwt.expiration-minutes:1440}") long expirationMinutes) {
        if (secret == null || secret.length() < 32) {
            throw new IllegalStateException(
                    "app.jwt.secret is missing or shorter than 32 characters. "
                            + "Set the JWT_SECRET environment variable or add it to backend/application-local.properties.");
        }
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.lifetime = Duration.ofMinutes(expirationMinutes);
    }

    public String createToken(Long userId) {
        Date now = new Date();
        return Jwts.builder()
                .subject(String.valueOf(userId))
                .issuedAt(now)
                .expiration(new Date(now.getTime() + lifetime.toMillis()))
                .signWith(key)
                .compact();
    }

    /** Returns the user id if the token is valid and unexpired, otherwise empty. */
    public Optional<Long> parseUserId(String token) {
        try {
            String subject = Jwts.parser().verifyWith(key).build()
                    .parseSignedClaims(token).getPayload().getSubject();
            return Optional.of(Long.valueOf(subject));
        } catch (JwtException | IllegalArgumentException ex) {
            return Optional.empty();
        }
    }
}
