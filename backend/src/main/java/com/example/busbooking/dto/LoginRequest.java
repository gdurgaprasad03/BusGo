package com.example.busbooking.dto;

import com.fasterxml.jackson.annotation.JsonAlias;
import jakarta.validation.constraints.NotBlank;

/** "identifier" is an email address or a 10-digit mobile number. The old name "email" is still accepted. */
public record LoginRequest(
        @JsonAlias("email")
        @NotBlank(message = "Email or mobile number is required") String identifier,
        @NotBlank(message = "Password is required") String password) {
}
