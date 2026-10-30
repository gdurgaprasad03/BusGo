package com.example.busbooking.dto;

/** A state or union territory with how many places are listed and how many have demo bus service. */
public record StateResponse(String name, String type, int placeCount, int servedPlaceCount) {
}
