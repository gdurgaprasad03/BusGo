package com.example.busbooking.integration;

import com.example.busbooking.dto.TripResponse;
import com.example.busbooking.entity.Trip;
import com.example.busbooking.repository.SeatCount;
import com.example.busbooking.repository.TripRepository;
import com.example.busbooking.repository.TripSeatRepository;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Sample trips stored in our own MySQL database (see DemoDataService). Everything it returns is labelled
 * DEMO. Seat availability is counted from the database, and fully booked or already departed trips are left out.
 */
@Component
@ConditionalOnProperty(name = "app.providers.demo.enabled", havingValue = "true", matchIfMissing = true)
public class DemoTripProvider implements TripProvider {

    private final TripRepository tripRepository;
    private final TripSeatRepository tripSeatRepository;

    public DemoTripProvider(TripRepository tripRepository, TripSeatRepository tripSeatRepository) {
        this.tripRepository = tripRepository;
        this.tripSeatRepository = tripSeatRepository;
    }

    @Override
    public String id() {
        return TripResponse.DEMO_PROVIDER;
    }

    @Override
    @Transactional(readOnly = true)
    public List<TripResponse> search(TripSearchCriteria c) {
        LocalDateTime dayStart = c.date().atStartOfDay();
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime windowStart = dayStart.isBefore(now) ? now : dayStart;

        List<Trip> trips = tripRepository.search(c.source(), c.destination(), windowStart, dayStart.plusDays(1)).stream()
                .filter(t -> c.busType() == null || t.getBus().getBusType() == c.busType())
                .filter(t -> c.departureFrom() == null || !t.getDepartureTime().toLocalTime().isBefore(c.departureFrom()))
                .filter(t -> c.departureTo() == null || !t.getDepartureTime().toLocalTime().isAfter(c.departureTo()))
                .toList();
        if (trips.isEmpty()) {
            return List.of();
        }

        Map<Long, Long> available = availableByTrip(trips);
        return trips.stream()
                .map(t -> TripResponse.from(t, available.getOrDefault(t.getId(), 0L)))
                .filter(r -> r.availableSeats() > 0) // fully booked trips are never listed
                .toList();
    }

    private Map<Long, Long> availableByTrip(List<Trip> trips) {
        List<Long> ids = trips.stream().map(Trip::getId).toList();
        if (ids.isEmpty()) {
            return Collections.emptyMap();
        }
        return tripSeatRepository.countAvailableByTripIds(ids).stream()
                .collect(Collectors.toMap(SeatCount::tripId, SeatCount::count));
    }
}
