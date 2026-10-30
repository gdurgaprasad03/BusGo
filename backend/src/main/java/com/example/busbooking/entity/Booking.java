package com.example.busbooking.entity;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.Table;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "bookings")
public class Booking {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** Human-friendly unique code shown on the ticket, e.g. BG7K2M9QXA. */
    private String reference;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id")
    private User user;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "trip_id")
    private Trip trip;

    @Enumerated(EnumType.STRING)
    private BookingStatus status;

    private BigDecimal totalAmount;
    private BigDecimal refundAmount;
    private String contactPhone;
    private String contactEmail;

    @Enumerated(EnumType.STRING)
    private PaymentMethod paymentMethod;

    private LocalDateTime createdAt;
    private LocalDateTime cancelledAt;

    @OneToMany(mappedBy = "booking", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<BookingSeat> seats = new ArrayList<>();

    protected Booking() {
    }

    public Booking(String reference, User user, Trip trip, BigDecimal totalAmount,
                   String contactPhone, String contactEmail, PaymentMethod paymentMethod) {
        this.reference = reference;
        this.user = user;
        this.trip = trip;
        this.status = BookingStatus.CONFIRMED;
        this.totalAmount = totalAmount;
        this.contactPhone = contactPhone;
        this.contactEmail = contactEmail;
        this.paymentMethod = paymentMethod;
        this.createdAt = LocalDateTime.now();
    }

    public void addSeat(BookingSeat seat) {
        seats.add(seat);
    }

    public void markCancelled(BigDecimal refund) {
        this.status = BookingStatus.CANCELLED;
        this.refundAmount = refund;
        this.cancelledAt = LocalDateTime.now();
    }

    public Long getId() { return id; }
    public String getReference() { return reference; }
    public User getUser() { return user; }
    public Trip getTrip() { return trip; }
    public BookingStatus getStatus() { return status; }
    public BigDecimal getTotalAmount() { return totalAmount; }
    public BigDecimal getRefundAmount() { return refundAmount; }
    public String getContactPhone() { return contactPhone; }
    public String getContactEmail() { return contactEmail; }
    public PaymentMethod getPaymentMethod() { return paymentMethod; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public LocalDateTime getCancelledAt() { return cancelledAt; }
    public List<BookingSeat> getSeats() { return seats; }
}
