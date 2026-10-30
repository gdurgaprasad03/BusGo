package com.example.busbooking.security;

import com.example.busbooking.dto.ApiError;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.Duration;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Slows down password guessing: at most {@code maxAttempts} POSTs per client address per minute to login,
 * register and reset-password. Counters are kept in memory (fine for one server; use a shared store when scaling out).
 * The address is the TCP peer, not X-Forwarded-For, which a client could fake.
 */
public class AuthRateLimitFilter extends OncePerRequestFilter {

    private static final Set<String> LIMITED_PATHS =
            Set.of("/api/auth/login", "/api/auth/register", "/api/auth/reset-password");
    private static final long WINDOW_MILLIS = Duration.ofMinutes(1).toMillis();

    private record Window(long startMillis, int count) { }

    private final Map<String, Window> windows = new ConcurrentHashMap<>();
    private final int maxAttempts;
    private final ObjectMapper objectMapper;

    public AuthRateLimitFilter(int maxAttempts, ObjectMapper objectMapper) {
        this.maxAttempts = maxAttempts;
        this.objectMapper = objectMapper;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return !"POST".equals(request.getMethod()) || !LIMITED_PATHS.contains(request.getRequestURI());
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        long now = System.currentTimeMillis();
        String key = request.getRemoteAddr() + "|" + request.getRequestURI();
        if (windows.size() > 10_000) {
            windows.values().removeIf(w -> now - w.startMillis() >= WINDOW_MILLIS);
        }
        Window w = windows.merge(key, new Window(now, 1),
                (old, fresh) -> now - old.startMillis() >= WINDOW_MILLIS ? fresh : new Window(old.startMillis(), old.count() + 1));
        if (w.count() > maxAttempts) {
            long retryAfter = Math.max(1, (WINDOW_MILLIS - (now - w.startMillis()) + 999) / 1000);
            response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
            response.setHeader("Retry-After", String.valueOf(retryAfter));
            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
            objectMapper.writeValue(response.getOutputStream(), ApiError.of(
                    429, "Too Many Requests", "Too many attempts. Please wait a minute and try again."));
            return;
        }
        chain.doFilter(request, response);
    }
}
