package com.example.busbooking.dto;

import com.example.busbooking.entity.TripSeat;

public record SeatResponse(String seatNumber, String deck, int row, int column, String status) {

    public static SeatResponse from(TripSeat seat) {
        return new SeatResponse(seat.getSeatNumber(), seat.getDeck().name(),
                seat.getSeatRow(), seat.getSeatCol(), seat.getStatus().name());
    }
}
