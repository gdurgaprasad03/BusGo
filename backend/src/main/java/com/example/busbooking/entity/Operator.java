package com.example.busbooking.entity;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.math.BigDecimal;

/** A bus company. Names and ratings are DEMO data. */
@Entity
@Table(name = "operators")
public class Operator {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String name;
    private BigDecimal rating;

    protected Operator() {
    }

    public Operator(String name, BigDecimal rating) {
        this.name = name;
        this.rating = rating;
    }

    public Long getId() { return id; }
    public String getName() { return name; }
    public BigDecimal getRating() { return rating; }
}
