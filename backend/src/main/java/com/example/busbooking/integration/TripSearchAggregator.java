package com.example.busbooking.integration;

import com.example.busbooking.dto.TripResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

/**
 * Asks every enabled {@link TripProvider} at the same time and merges the answers.
 * A provider that fails or is too slow is skipped (and reported in {@link Outcome#failedProviders()})
 * so the others can still answer. Results are de-duplicated and sorted by departure time.
 */
@Service
public class TripSearchAggregator {

    private static final Logger log = LoggerFactory.getLogger(TripSearchAggregator.class);

    /** The merged trips plus the ids of providers that could not answer. */
    public record Outcome(List<TripResponse> trips, List<String> failedProviders) {}

    private final List<TripProvider> providers;
    private final Duration timeout;
    private final ExecutorService executor = Executors.newCachedThreadPool(r -> {
        Thread t = new Thread(r, "trip-provider");
        t.setDaemon(true);
        return t;
    });

    public TripSearchAggregator(List<TripProvider> providers,
                                @Value("${app.providers.timeout-ms:5000}") long timeoutMs) {
        this.providers = providers;
        this.timeout = Duration.ofMillis(timeoutMs);
    }

    public Outcome search(TripSearchCriteria criteria) {
        Map<TripProvider, CompletableFuture<List<TripResponse>>> pending = new LinkedHashMap<>();
        for (TripProvider provider : providers) {
            pending.put(provider, CompletableFuture.supplyAsync(() -> provider.search(criteria), executor));
        }

        // De-duplicate on provider + that provider's own trip id, keeping the first one seen.
        Map<String, TripResponse> unique = new LinkedHashMap<>();
        List<String> failed = new ArrayList<>();
        for (Map.Entry<TripProvider, CompletableFuture<List<TripResponse>>> entry : pending.entrySet()) {
            String id = entry.getKey().id();
            try {
                for (TripResponse trip : entry.getValue().get(timeout.toMillis(), TimeUnit.MILLISECONDS)) {
                    unique.putIfAbsent(trip.provider() + ":" + trip.tripId(), trip);
                }
            } catch (TimeoutException e) {
                entry.getValue().cancel(true);
                failed.add(id);
                log.warn("Trip provider '{}' did not answer within {} ms", id, timeout.toMillis());
            } catch (Exception e) {
                failed.add(id);
                // Only the exception type is logged: provider errors can contain URLs or tokens.
                log.warn("Trip provider '{}' failed: {}", id, e.getCause() != null ? e.getCause().getClass().getSimpleName() : e.getClass().getSimpleName());
            }
        }
        List<TripResponse> trips = unique.values().stream()
                .sorted(Comparator.comparing(TripResponse::departureTime).thenComparing(TripResponse::fare))
                .toList();
        return new Outcome(trips, failed);
    }
}
