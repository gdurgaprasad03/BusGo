package com.example.busbooking.exception;

import org.springframework.http.HttpStatus;

/** 503: a feature that needs server configuration (for example Google sign-in) is not set up. */
public class ServiceUnavailableException extends ApiException {
    public ServiceUnavailableException(String message) {
        super(HttpStatus.SERVICE_UNAVAILABLE, message);
    }
}
