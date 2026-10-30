package com.example.busbooking.exception;

import org.springframework.http.HttpStatus;

/** 403: logged in, but trying to touch someone else's data. */
public class ForbiddenException extends ApiException {
    public ForbiddenException(String message) {
        super(HttpStatus.FORBIDDEN, message);
    }
}
