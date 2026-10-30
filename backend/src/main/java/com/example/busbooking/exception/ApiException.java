package com.example.busbooking.exception;

import org.springframework.http.HttpStatus;

/** Base class for business errors. Each subclass carries the HTTP status it should produce. */
public abstract class ApiException extends RuntimeException {

    private final HttpStatus status;

    protected ApiException(HttpStatus status, String message) {
        super(message);
        this.status = status;
    }

    public HttpStatus getStatus() {
        return status;
    }
}
