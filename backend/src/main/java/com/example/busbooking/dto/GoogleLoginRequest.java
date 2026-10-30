package com.example.busbooking.dto;

import jakarta.validation.constraints.NotBlank;

/** The Google ID token the app received from Google. The server verifies it; nothing else is trusted. */
public record GoogleLoginRequest(@NotBlank(message = "Google token is required") String idToken) {
}
