package com.example.busbooking.dto;

import com.example.busbooking.entity.Trip;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.LocalDateTime;

/**
 * One trip as shown in search results and on the bus details screen.
 * {@code provider} says which provider supplied it, {@code dataSource} is DEMO (sample data) or LIVE
 * (a real, authorised provider), and {@code bookable} says whether this app can book it.
 */
public record TripResponse(
        Long tripId,
        String operatorName,
        BigDecimal operatorRating,
        String busType,
        String source,
        String destination,
        LocalDateTime departureTime,
        LocalDateTime arrivalTime,
        long durationMinutes,
        BigDecimal fare,
        long availableSeats,
        int totalSeats,
        String boardingPoint,
        String droppingPoint,
        String provider,
        String dataSource,
        boolean bookable) {

    public static final String DEMO_PROVIDER = "demo";
    public static final String DATA_SOURCE_DEMO = "DEMO";

    /** A trip stored in this app's own database (the demo provider). */
    public static TripResponse from(Trip trip, long availableSeats) {
        return new TripResponse(
                trip.getId(),
                trip.getBus().getOperator().getName(),
                trip.getBus().getOperator().getRating(),
                trip.getBus().getBusType().name(),
                trip.getSource(),
                trip.getDestination(),
                trip.getDepartureTime(),
                trip.getArrivalTime(),
                Duration.between(trip.getDepartureTime(), trip.getArrivalTime()).toMinutes(),
                trip.getFare(),
                availableSeats,
                trip.getBus().getTotalSeats(),
                trip.getBoardingPoint(),
                trip.getDroppingPoint(),
                DEMO_PROVIDER,
                DATA_SOURCE_DEMO,
                true);
    }
}
