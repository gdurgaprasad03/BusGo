package com.example.busbooking.entity;

import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

/** Links a booking to one trip seat and records who sits there. */
@Entity
@Table(name = "booking_seats")
public class BookingSeat {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "booking_id")
    private Booking booking;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "trip_seat_id")
    private TripSeat tripSeat;

    /**
     * Equals the trip seat id while the booking is CONFIRMED, NULL after cancellation.
     * The column has a UNIQUE constraint, so the database itself refuses a second active
     * booking of the same seat even if application code had a bug.
     */
    private Long activeTripSeatId;

    private String passengerName;
    private int passengerAge;
    private String passengerGender;

    protected BookingSeat() {
    }

    public BookingSeat(Booking booking, TripSeat tripSeat, String passengerName,
                       int passengerAge, String passengerGender) {
        this.booking = booking;
        this.tripSeat = tripSeat;
        this.activeTripSeatId = tripSeat.getId();
        this.passengerName = passengerName;
        this.passengerAge = passengerAge;
        this.passengerGender = passengerGender;
    }

    public void release() {
        this.activeTripSeatId = null;
    }

    public Long getId() { return id; }
    public Booking getBooking() { return booking; }
    public TripSeat getTripSeat() { return tripSeat; }
    public Long getActiveTripSeatId() { return activeTripSeatId; }
    public String getPassengerName() { return passengerName; }
    public int getPassengerAge() { return passengerAge; }
    public String getPassengerGender() { return passengerGender; }
}
