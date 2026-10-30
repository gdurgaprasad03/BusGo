package com.example.busbooking.dto;

import com.example.busbooking.entity.SavedPassenger;

public record SavedPassengerResponse(Long id, String name, int age, String gender) {

    public static SavedPassengerResponse from(SavedPassenger p) {
        return new SavedPassengerResponse(p.getId(), p.getName(), p.getAge(), p.getGender());
    }
}
