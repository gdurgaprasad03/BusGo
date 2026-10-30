package com.example.busbooking.integration;

import com.example.busbooking.entity.BusType;

import java.time.LocalDate;
import java.time.LocalTime;

/** What the user asked for. Place names are already normalised (see CityCatalog.canonicalName). */
public record TripSearchCriteria(String source, String destination, LocalDate date,
                                 LocalTime departureFrom, LocalTime departureTo, BusType busType) {
}
