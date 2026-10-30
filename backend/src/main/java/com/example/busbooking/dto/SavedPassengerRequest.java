package com.example.busbooking.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record SavedPassengerRequest(
        @NotBlank(message = "Passenger name is required")
        @Size(max = 100, message = "Passenger name must be at most 100 characters")
        String name,

        @NotNull(message = "Passenger age is required")
        @Min(value = 1, message = "Age must be at least 1")
        @Max(value = 120, message = "Age must be at most 120")
        Integer age,

        @NotBlank(message = "Gender is required")
        @Pattern(regexp = "MALE|FEMALE|OTHER", message = "Gender must be MALE, FEMALE or OTHER")
        String gender) {
}
