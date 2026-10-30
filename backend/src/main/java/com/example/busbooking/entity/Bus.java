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

/**
 * A PHYSICAL vehicle. It exists once, regardless of how many journeys it runs.
 * (A scheduled journey of this vehicle is a {@link Trip}.)
 */
@Entity
@Table(name = "buses")
public class Bus {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "operator_id")
    private Operator operator;

    private String registrationNumber;

    @Enumerated(EnumType.STRING)
    private BusType busType;

    private int totalSeats;

    protected Bus() {
    }

    public Bus(Operator operator, String registrationNumber, BusType busType, int totalSeats) {
        this.operator = operator;
        this.registrationNumber = registrationNumber;
        this.busType = busType;
        this.totalSeats = totalSeats;
    }

    public Long getId() { return id; }
    public Operator getOperator() { return operator; }
    public String getRegistrationNumber() { return registrationNumber; }
    public BusType getBusType() { return busType; }
    public int getTotalSeats() { return totalSeats; }
}
