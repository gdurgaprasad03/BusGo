package com.example.busbooking.entity;

import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

/** One seat on one specific trip (seat inventory). seatRow/seatCol let the app draw the layout. */
@Entity
@Table(name = "trip_seats")
public class TripSeat {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "trip_id")
    private Trip trip;

    private String seatNumber;

    @Enumerated(EnumType.STRING)
    private Deck deck;

    private int seatRow;
    private int seatCol;

    @Enumerated(EnumType.STRING)
    private SeatStatus status;

    protected TripSeat() {
    }

    public Long getId() { return id; }
    public Trip getTrip() { return trip; }
    public String getSeatNumber() { return seatNumber; }
    public Deck getDeck() { return deck; }
    public int getSeatRow() { return seatRow; }
    public int getSeatCol() { return seatCol; }
    public SeatStatus getStatus() { return status; }

    public void setStatus(SeatStatus status) { this.status = status; }
}
