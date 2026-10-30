package com.example.busbooking.service;

import com.example.busbooking.catalog.CityCatalog;
import com.example.busbooking.dto.SeatLayoutResponse;
import com.example.busbooking.dto.SeatResponse;
import com.example.busbooking.dto.TripResponse;
import com.example.busbooking.entity.BusType;
import com.example.busbooking.entity.SeatStatus;
import com.example.busbooking.entity.Trip;
import com.example.busbooking.entity.TripSeat;
import com.example.busbooking.exception.BadRequestException;
import com.example.busbooking.exception.ResourceNotFoundException;
import com.example.busbooking.integration.TripSearchAggregator;
import com.example.busbooking.integration.TripSearchCriteria;
import com.example.busbooking.repository.TripRepository;
import com.example.busbooking.repository.TripSeatRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

@Service
public class TripService {

    private final TripRepository tripRepository;
    private final TripSeatRepository tripSeatRepository;
    private final TripSearchAggregator aggregator;
    private final CityCatalog cityCatalog;

    public TripService(TripRepository tripRepository, TripSeatRepository tripSeatRepository,
                       TripSearchAggregator aggregator, CityCatalog cityCatalog) {
        this.tripRepository = tripRepository;
        this.tripSeatRepository = tripSeatRepository;
        this.aggregator = aggregator;
        this.cityCatalog = cityCatalog;
    }

    /**
     * Validates the request, turns what the user typed into catalog names ("bangalore" becomes "Bengaluru"),
     * and asks all trip providers. Trips that already departed, or have no free seat, are not returned.
     */
    public TripSearchAggregator.Outcome search(String source, String destination, LocalDate date,
                                               LocalTime departureFrom, LocalTime departureTo, BusType busType) {
        String from = cityCatalog.canonicalName(source);
        String to = cityCatalog.canonicalName(destination);
        if (from.isEmpty() || to.isEmpty()) {
            throw new BadRequestException("Source and destination are required");
        }
        if (from.equalsIgnoreCase(to)) {
            throw new BadRequestException("Source and destination must be different");
        }
        if (departureFrom != null && departureTo != null && departureFrom.isAfter(departureTo)) {
            throw new BadRequestException("departureFrom must not be after departureTo");
        }
        return aggregator.search(new TripSearchCriteria(from, to, date, departureFrom, departureTo, busType));
    }

    @Transactional(readOnly = true)
    public TripResponse getTrip(Long tripId) {
        Trip trip = findTrip(tripId);
        return TripResponse.from(trip, tripSeatRepository.countByTripIdAndStatus(tripId, SeatStatus.AVAILABLE));
    }

    @Transactional(readOnly = true)
    public SeatLayoutResponse getSeats(Long tripId) {
        Trip trip = findTrip(tripId);
        List<TripSeat> seats = tripSeatRepository.findByTripIdOrderByDeckAscSeatRowAscSeatColAsc(tripId);
        BusType type = trip.getBus().getBusType();
        long available = seats.stream().filter(s -> s.getStatus() == SeatStatus.AVAILABLE).count();
        int rows = seats.stream().mapToInt(TripSeat::getSeatRow).max().orElse(0);
        int columns = seats.stream().mapToInt(TripSeat::getSeatCol).max().orElse(0);
        return new SeatLayoutResponse(tripId, type.name(), type.isSleeper() ? 2 : 1, rows, columns,
                type.isSleeper() ? 1 : 2, available, seats.stream().map(SeatResponse::from).toList());
    }

    private Trip findTrip(Long tripId) {
        return tripRepository.findDetailedById(tripId)
                .orElseThrow(() -> new ResourceNotFoundException("Trip " + tripId + " not found"));
    }
}
