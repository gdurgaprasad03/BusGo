package com.example.busbooking.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** Step 2 of "forgot password": the 6-digit code that was emailed, plus the new password. */
public record ResetPasswordRequest(
        @NotBlank(message = "Email is required") @Email(message = "Enter a valid email address") String email,

        @NotBlank(message = "Enter the 6-digit code from the email")
        @Pattern(regexp = "\\d{6}", message = "The code is 6 digits")
        String code,

        @NotBlank(message = "New password is required")
        @Size(min = 8, max = 72, message = "Password must be 8 to 72 characters")
        String newPassword) {
}
