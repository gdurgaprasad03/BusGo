package com.example.busbooking.dto;

import com.example.busbooking.entity.Booking;
import com.example.busbooking.entity.BookingSeat;
import com.example.busbooking.entity.BookingStatus;
import com.example.busbooking.entity.Trip;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

/** Everything the ticket / booking-details / confirmation screens need. */
public record BookingResponse(
        Long bookingId,
        String bookingReference,
        String status,
        boolean upcoming,
        Long tripId,
        String operatorName,
        String busType,
        String source,
        String destination,
        LocalDateTime departureTime,
        LocalDateTime arrivalTime,
        String boardingPoint,
        String droppingPoint,
        BigDecimal totalAmount,
        BigDecimal refundAmount,
        String paymentMethod,
        String contactPhone,
        String contactEmail,
        LocalDateTime bookedAt,
        LocalDateTime cancelledAt,
        List<PassengerResponse> passengers) {

    public record PassengerResponse(String seatNumber, String name, int age, String gender) {
        static PassengerResponse from(BookingSeat bs) {
            return new PassengerResponse(bs.getTripSeat().getSeatNumber(), bs.getPassengerName(),
                    bs.getPassengerAge(), bs.getPassengerGender());
        }
    }

    /** Must be called inside a transaction because it reads lazy relations. */
    public static BookingResponse from(Booking b, LocalDateTime now) {
        Trip t = b.getTrip();
        boolean upcoming = b.getStatus() == BookingStatus.CONFIRMED && t.getDepartureTime().isAfter(now);
        return new BookingResponse(
                b.getId(), b.getReference(), b.getStatus().name(), upcoming,
                t.getId(), t.getBus().getOperator().getName(), t.getBus().getBusType().name(),
                t.getSource(), t.getDestination(), t.getDepartureTime(), t.getArrivalTime(),
                t.getBoardingPoint(), t.getDroppingPoint(),
                b.getTotalAmount(), b.getRefundAmount(), b.getPaymentMethod().name(),
                b.getContactPhone(), b.getContactEmail(), b.getCreatedAt(), b.getCancelledAt(),
                b.getSeats().stream().map(PassengerResponse::from).toList());
    }
}
