package com.example.busbooking.dto;

import java.util.List;

/**
 * Seat map for one trip. The app draws a grid per deck using row/column, and leaves a gap
 * after column {@code aisleAfterColumn}. Seater buses are 2+2 (aisle after column 2),
 * sleeper buses are 1+2 on two decks (aisle after column 1).
 */
public record SeatLayoutResponse(
        Long tripId,
        String busType,
        int decks,
        int rows,
        int columns,
        int aisleAfterColumn,
        long availableSeats,
        List<SeatResponse> seats) {
}
