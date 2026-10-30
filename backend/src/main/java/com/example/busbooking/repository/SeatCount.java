package com.example.busbooking.repository;

/** Result row of the "available seats per trip" query. */
public record SeatCount(Long tripId, long count) {
}
