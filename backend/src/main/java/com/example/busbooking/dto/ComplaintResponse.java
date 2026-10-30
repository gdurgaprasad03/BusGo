package com.example.busbooking.dto;

import com.example.busbooking.entity.Complaint;

import java.time.LocalDateTime;

public record ComplaintResponse(Long id, String reference, String bookingReference, String subject,
                                String message, String status, LocalDateTime createdAt) {

    public static ComplaintResponse from(Complaint c) {
        return new ComplaintResponse(c.getId(), String.format("CMP%05d", c.getId()), c.getBookingReference(),
                c.getSubject(), c.getMessage(), c.getStatus(), c.getCreatedAt());
    }
}
