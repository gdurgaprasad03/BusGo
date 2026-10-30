package com.example.busbooking.controller;

import com.example.busbooking.dto.SeatLayoutResponse;
import com.example.busbooking.dto.TripResponse;
import com.example.busbooking.entity.BusType;
import com.example.busbooking.integration.TripSearchAggregator;
import com.example.busbooking.service.TripService;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

@RestController
@RequestMapping("/api/trips")
public class TripController {

    private final TripService tripService;

    public TripController(TripService tripService) {
        this.tripService = tripService;
    }

    /** GET /api/trips/search?source=Kurnool&destination=Hyderabad&date=2026-10-25[&departureFrom=18:00&departureTo=23:59&busType=AC_SLEEPER] */
    @GetMapping("/search")
    public ResponseEntity<List<TripResponse>> search(
            @RequestParam String source,
            @RequestParam String destination,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.TIME) LocalTime departureFrom,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.TIME) LocalTime departureTo,
            @RequestParam(required = false) BusType busType) {
        TripSearchAggregator.Outcome outcome =
                tripService.search(source, destination, date, departureFrom, departureTo, busType);
        ResponseEntity.BodyBuilder response = ResponseEntity.ok();
        if (!outcome.failedProviders().isEmpty()) {
            // Partial failure: some providers could not answer. The trips that did arrive are still returned.
            response.header("X-Provider-Warnings", String.join(",", outcome.failedProviders()));
        }
        return response.body(outcome.trips());
    }

    @GetMapping("/{tripId}")
    public TripResponse get(@PathVariable Long tripId) {
        return tripService.getTrip(tripId);
    }

    @GetMapping("/{tripId}/seats")
    public SeatLayoutResponse seats(@PathVariable Long tripId) {
        return tripService.getSeats(tripId);
    }
}
