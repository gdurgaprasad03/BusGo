package com.example.busbooking.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ComplaintRequest(
        /** Optional: the reference of one of the user's own bookings. */
        @Size(max = 20, message = "Booking reference is too long")
        String bookingReference,

        @NotBlank(message = "Subject is required")
        @Size(max = 120, message = "Subject must be at most 120 characters")
        String subject,

        @NotBlank(message = "Please describe the problem")
        @Size(min = 10, max = 1000, message = "Description must be 10 to 1000 characters")
        String message) {
}
