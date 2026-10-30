package com.example.busbooking.entity;

import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/** A SCHEDULED JOURNEY: one bus, one route, one departure date/time. Seats belong to a trip. */
@Entity
@Table(name = "trips")
public class Trip {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "bus_id")
    private Bus bus;

    private String source;
    private String destination;
    private LocalDateTime departureTime;
    private LocalDateTime arrivalTime;
    private BigDecimal fare;
    private String boardingPoint;
    private String droppingPoint;

    protected Trip() {
    }

    public Trip(Bus bus, String source, String destination, LocalDateTime departureTime,
                LocalDateTime arrivalTime, BigDecimal fare, String boardingPoint, String droppingPoint) {
        this.bus = bus;
        this.source = source;
        this.destination = destination;
        this.departureTime = departureTime;
        this.arrivalTime = arrivalTime;
        this.fare = fare;
        this.boardingPoint = boardingPoint;
        this.droppingPoint = droppingPoint;
    }

    public Long getId() { return id; }
    public Bus getBus() { return bus; }
    public String getSource() { return source; }
    public String getDestination() { return destination; }
    public LocalDateTime getDepartureTime() { return departureTime; }
    public LocalDateTime getArrivalTime() { return arrivalTime; }
    public BigDecimal getFare() { return fare; }
    public String getBoardingPoint() { return boardingPoint; }
    public String getDroppingPoint() { return droppingPoint; }
}
