package com.example.busbooking.service;

import com.example.busbooking.catalog.CityCatalog;
import com.example.busbooking.dto.PlaceResponse;
import com.example.busbooking.dto.StateResponse;
import com.example.busbooking.exception.BadRequestException;
import com.example.busbooking.repository.TripRepository;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

/** Place autocomplete and the state list. Keeps city COVERAGE (the catalog) separate from bus SERVICE (trips). */
@Service
public class PlaceService {

    private static final Duration CACHE_TTL = Duration.ofSeconds(60);

    private final CityCatalog catalog;
    private final TripRepository tripRepository;

    private volatile Set<String> servedCache = Set.of();
    private volatile Instant servedLoadedAt = Instant.EPOCH;

    public PlaceService(CityCatalog catalog, TripRepository tripRepository) {
        this.catalog = catalog;
        this.tripRepository = tripRepository;
    }

    public List<PlaceResponse> search(String query, String state, int limit) {
        if (state != null && !state.isBlank() && catalog.states().stream().noneMatch(s -> s.name().equalsIgnoreCase(state.trim()))) {
            throw new BadRequestException("Unknown state or union territory: " + state.trim());
        }
        Set<String> served = servedPlaces();
        return catalog.search(query, state, limit).stream()
                .map(c -> new PlaceResponse(c.name(), c.state(), served.contains(c.name().toLowerCase(Locale.ROOT))))
                .toList();
    }

    public List<StateResponse> states() {
        Set<String> served = servedPlaces();
        return catalog.states().stream().map(s -> {
            var inState = catalog.citiesInState(s.name());
            int servedCount = (int) inState.stream().filter(c -> served.contains(c.name().toLowerCase(Locale.ROOT))).count();
            return new StateResponse(s.name(), s.type(), inState.size(), servedCount);
        }).toList();
    }

    /** Lower-case names of places that have at least one trip, cached briefly. */
    private Set<String> servedPlaces() {
        if (Duration.between(servedLoadedAt, Instant.now()).compareTo(CACHE_TTL) > 0) {
            Set<String> names = new HashSet<>();
            tripRepository.distinctSources().forEach(n -> names.add(n.toLowerCase(Locale.ROOT)));
            tripRepository.distinctDestinations().forEach(n -> names.add(n.toLowerCase(Locale.ROOT)));
            servedCache = names;
            servedLoadedAt = Instant.now();
        }
        return servedCache;
    }
}
