package com.example.busbooking;

import com.example.busbooking.dto.TripResponse;
import com.example.busbooking.integration.TripProvider;
import com.example.busbooking.integration.TripSearchAggregator;
import com.example.busbooking.integration.TripSearchCriteria;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** Plain unit test (no Spring): partial failure, timeouts, de-duplication and sorting. */
class TripSearchAggregatorTest {

    private static final TripSearchCriteria CRITERIA =
            new TripSearchCriteria("A", "B", LocalDate.now().plusDays(1), null, null, null);

    private static TripResponse trip(String provider, long id, int hour, String dataSource) {
        LocalDateTime departure = LocalDate.now().plusDays(1).atTime(hour, 0);
        return new TripResponse(id, "Operator " + provider, new BigDecimal("4.0"), "AC_SEATER", "A", "B",
                departure, departure.plusHours(4), 240, new BigDecimal("500"), 10, 40, "x", "y",
                provider, dataSource, "demo".equals(provider));
    }

    private static TripProvider provider(String id, java.util.function.Supplier<List<TripResponse>> action) {
        return new TripProvider() {
            @Override public String id() { return id; }
            @Override public List<TripResponse> search(TripSearchCriteria criteria) { return action.get(); }
        };
    }

    @Test
    void mergesProvidersAndSortsByDepartureTime() {
        var aggregator = new TripSearchAggregator(List.of(
                provider("demo", () -> List.of(trip("demo", 1, 20, "DEMO"), trip("demo", 2, 6, "DEMO"))),
                provider("live", () -> List.of(trip("live", 7, 12, "LIVE")))), 2000);

        var outcome = aggregator.search(CRITERIA);
        assertEquals(List.of(6, 12, 20), outcome.trips().stream().map(t -> t.departureTime().getHour()).toList());
        assertTrue(outcome.failedProviders().isEmpty());
        // Each result keeps its own source label: demo and live trips are never mixed up.
        assertEquals("LIVE", outcome.trips().get(1).dataSource());
        assertEquals("DEMO", outcome.trips().get(0).dataSource());
    }

    @Test
    void aFailingProviderDoesNotBreakTheSearch() {
        var aggregator = new TripSearchAggregator(List.of(
                provider("demo", () -> List.of(trip("demo", 1, 8, "DEMO"))),
                provider("broken", () -> { throw new IllegalStateException("secret-token-123 leaked in message"); })), 2000);

        var outcome = aggregator.search(CRITERIA);
        assertEquals(1, outcome.trips().size());
        assertEquals(List.of("broken"), outcome.failedProviders());
    }

    @Test
    void aSlowProviderIsSkippedAfterTheTimeout() {
        var aggregator = new TripSearchAggregator(List.of(
                provider("demo", () -> List.of(trip("demo", 1, 8, "DEMO"))),
                provider("slow", () -> {
                    try { Thread.sleep(3000); } catch (InterruptedException ignored) { Thread.currentThread().interrupt(); }
                    return List.of(trip("slow", 9, 9, "LIVE"));
                })), 300);

        long start = System.currentTimeMillis();
        var outcome = aggregator.search(CRITERIA);
        assertTrue(System.currentTimeMillis() - start < 2500, "must not wait for the slow provider");
        assertEquals(1, outcome.trips().size());
        assertEquals(List.of("slow"), outcome.failedProviders());
    }

    @Test
    void duplicateTripsFromTheSameProviderAreRemoved() {
        var aggregator = new TripSearchAggregator(List.of(
                provider("demo", () -> List.of(trip("demo", 1, 8, "DEMO"), trip("demo", 1, 8, "DEMO"), trip("demo", 2, 9, "DEMO")))), 2000);
        assertEquals(2, aggregator.search(CRITERIA).trips().size());
    }

    @Test
    void sameIdFromDifferentProvidersIsKeptSeparately() {
        var aggregator = new TripSearchAggregator(List.of(
                provider("demo", () -> List.of(trip("demo", 5, 8, "DEMO"))),
                provider("live", () -> List.of(trip("live", 5, 9, "LIVE")))), 2000);
        assertEquals(2, aggregator.search(CRITERIA).trips().size());
    }
}
