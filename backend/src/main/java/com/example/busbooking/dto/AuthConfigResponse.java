package com.example.busbooking.dto;

/**
 * Lets the app know which optional features this server supports, so it can disable or explain unavailable ones.
 * {@code emailEnabled} = the server really sends email (SMTP configured); without it, reset codes cannot be delivered.
 */
public record AuthConfigResponse(boolean googleEnabled, boolean emailEnabled) {
}
