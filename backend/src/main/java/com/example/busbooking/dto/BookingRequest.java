package com.example.busbooking.dto;

import com.example.busbooking.entity.PaymentMethod;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.util.List;

/** Note there is no price field: the backend always calculates the amount itself. */
public record BookingRequest(
        @NotNull(message = "Trip is required") Long tripId,

        @NotEmpty(message = "Select at least one seat")
        @Size(max = 6, message = "You can book at most 6 seats at a time")
        List<@Valid PassengerRequest> passengers,

        @NotBlank(message = "Contact phone is required")
        @Pattern(regexp = "\\d{10}", message = "Phone must be 10 digits")
        String contactPhone,

        @NotBlank(message = "Contact email is required")
        @Email(message = "Enter a valid email address")
        String contactEmail,

        @NotNull(message = "Payment method is required") PaymentMethod paymentMethod) {
}
