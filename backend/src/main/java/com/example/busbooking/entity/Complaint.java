package com.example.busbooking.entity;

import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

import java.time.LocalDateTime;

/** A support complaint raised by a user, optionally about one of their bookings. */
@Entity
@Table(name = "complaints")
public class Complaint {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id")
    private User user;

    private String bookingReference;
    private String subject;
    private String message;
    private String status;
    private LocalDateTime createdAt;

    protected Complaint() {
    }

    public Complaint(User user, String bookingReference, String subject, String message) {
        this.user = user;
        this.bookingReference = bookingReference;
        this.subject = subject;
        this.message = message;
        this.status = "OPEN";
        this.createdAt = LocalDateTime.now();
    }

    public Long getId() { return id; }
    public User getUser() { return user; }
    public String getBookingReference() { return bookingReference; }
    public String getSubject() { return subject; }
    public String getMessage() { return message; }
    public String getStatus() { return status; }
    public LocalDateTime getCreatedAt() { return createdAt; }
}
