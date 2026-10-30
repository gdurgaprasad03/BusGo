package com.example.busbooking.exception;

import org.springframework.http.HttpStatus;

/** 401: not logged in, or wrong credentials. */
public class UnauthorizedException extends ApiException {
    public UnauthorizedException(String message) {
        super(HttpStatus.UNAUTHORIZED, message);
    }
}
