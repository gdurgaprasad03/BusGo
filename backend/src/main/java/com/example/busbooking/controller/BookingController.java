package com.example.busbooking.controller;

import com.example.busbooking.dto.BookingRequest;
import com.example.busbooking.dto.BookingResponse;
import com.example.busbooking.service.BookingService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/** Every method here requires a valid JWT (see SecurityConfig). The user id always comes from the token. */
@RestController
@RequestMapping("/api/bookings")
public class BookingController {

    private final BookingService bookingService;

    public BookingController(BookingService bookingService) {
        this.bookingService = bookingService;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public BookingResponse create(@AuthenticationPrincipal Long userId, @Valid @RequestBody BookingRequest request) {
        return bookingService.createBooking(userId, request);
    }

    @GetMapping("/my")
    public List<BookingResponse> mine(@AuthenticationPrincipal Long userId) {
        return bookingService.myBookings(userId);
    }

    @GetMapping("/{bookingId}")
    public BookingResponse get(@AuthenticationPrincipal Long userId, @PathVariable Long bookingId) {
        return bookingService.getBooking(userId, bookingId);
    }

    @PatchMapping("/{bookingId}/cancel")
    public BookingResponse cancel(@AuthenticationPrincipal Long userId, @PathVariable Long bookingId) {
        return bookingService.cancelBooking(userId, bookingId);
    }
}
