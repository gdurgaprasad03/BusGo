package com.example.busbooking.exception;

import org.springframework.http.HttpStatus;

/** 409: the request conflicts with current state (duplicate email, seat taken, already cancelled). */
public class ConflictException extends ApiException {
    public ConflictException(String message) {
        super(HttpStatus.CONFLICT, message);
    }
}
