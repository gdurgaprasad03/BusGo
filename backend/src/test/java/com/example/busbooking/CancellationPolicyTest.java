package com.example.busbooking;

import com.example.busbooking.service.CancellationPolicy;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.assertEquals;

/** Plain unit test (no Spring): checks the refund percentages exactly. */
class CancellationPolicyTest {

    private final LocalDateTime now = LocalDateTime.of(2026, 10, 20, 12, 0);
    private final BigDecimal total = new BigDecimal("1000.00");

    @Test
    void ninetyPercentRefundWhen24HoursOrMoreBeforeDeparture() {
        assertEquals(new BigDecimal("900.00"), CancellationPolicy.refundFor(total, now.plusHours(24), now));
        assertEquals(new BigDecimal("900.00"), CancellationPolicy.refundFor(total, now.plusDays(5), now));
    }

    @Test
    void fiftyPercentRefundBetween6And24Hours() {
        assertEquals(new BigDecimal("500.00"), CancellationPolicy.refundFor(total, now.plusHours(23), now));
        assertEquals(new BigDecimal("500.00"), CancellationPolicy.refundFor(total, now.plusHours(6), now));
    }

    @Test
    void noRefundUnder6Hours() {
        assertEquals(new BigDecimal("0.00"), CancellationPolicy.refundFor(total, now.plusHours(5), now));
    }
}
