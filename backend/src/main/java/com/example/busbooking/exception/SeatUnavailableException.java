package com.example.busbooking.exception;

import java.util.List;

/** 409: at least one requested seat is already booked. Nothing is booked in that case. */
public class SeatUnavailableException extends ConflictException {
    public SeatUnavailableException(List<String> seatNumbers) {
        super("Seat(s) no longer available: " + String.join(", ", seatNumbers));
    }
}
