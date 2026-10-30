package com.example.busbooking.exception;

import org.springframework.http.HttpStatus;

/** 404: the trip / booking / user does not exist. */
public class ResourceNotFoundException extends ApiException {
    public ResourceNotFoundException(String message) {
        super(HttpStatus.NOT_FOUND, message);
    }
}
