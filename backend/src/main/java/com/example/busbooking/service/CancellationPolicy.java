package com.example.busbooking.service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Duration;
import java.time.LocalDateTime;

/**
 * DEMO cancellation policy (not a real operator policy):
 * <ul>
 *   <li>24 hours or more before departure: 90% refund</li>
 *   <li>6 to 24 hours before departure: 50% refund</li>
 *   <li>less than 6 hours before departure: no refund</li>
 * </ul>
 * Cancelling after departure is not allowed. Seats are always released.
 */
public final class CancellationPolicy {

    private CancellationPolicy() {
    }

    public static BigDecimal refundFor(BigDecimal total, LocalDateTime departure, LocalDateTime now) {
        long hours = Duration.between(now, departure).toHours();
        BigDecimal percent = hours >= 24 ? BigDecimal.valueOf(90)
                : hours >= 6 ? BigDecimal.valueOf(50)
                : BigDecimal.ZERO;
        return total.multiply(percent).divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
    }
}
