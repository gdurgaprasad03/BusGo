package com.example.busbooking.dto;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.time.LocalDateTime;
import java.util.Map;

/** The single JSON shape used for every error response. */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record ApiError(LocalDateTime timestamp, int status, String error, String message,
                       Map<String, String> fieldErrors) {

    public static ApiError of(int status, String error, String message) {
        return new ApiError(LocalDateTime.now(), status, error, message, null);
    }

    public static ApiError of(int status, String error, String message, Map<String, String> fieldErrors) {
        return new ApiError(LocalDateTime.now(), status, error, message, fieldErrors);
    }
}
