package com.example.busbooking.service;

import com.example.busbooking.dto.ComplaintRequest;
import com.example.busbooking.dto.ComplaintResponse;
import com.example.busbooking.entity.Booking;
import com.example.busbooking.entity.Complaint;
import com.example.busbooking.exception.BadRequestException;
import com.example.busbooking.exception.ResourceNotFoundException;
import com.example.busbooking.repository.BookingRepository;
import com.example.busbooking.repository.ComplaintRepository;
import com.example.busbooking.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class ComplaintService {

    private final ComplaintRepository complaintRepository;
    private final BookingRepository bookingRepository;
    private final UserRepository userRepository;

    public ComplaintService(ComplaintRepository complaintRepository, BookingRepository bookingRepository,
                            UserRepository userRepository) {
        this.complaintRepository = complaintRepository;
        this.bookingRepository = bookingRepository;
        this.userRepository = userRepository;
    }

    @Transactional
    public ComplaintResponse raise(Long userId, ComplaintRequest request) {
        var user = userRepository.findById(userId).orElseThrow(() -> new ResourceNotFoundException("User not found"));
        String reference = request.bookingReference() == null ? "" : request.bookingReference().trim().toUpperCase();
        String bookingReference = null;
        if (!reference.isEmpty()) {
            // Only the user's own bookings can be referenced.
            boolean owned = bookingRepository.findByUserIdOrderByCreatedAtDesc(userId).stream()
                    .map(Booking::getReference).anyMatch(reference::equals);
            if (!owned) {
                throw new BadRequestException("Booking " + reference + " was not found in your bookings");
            }
            bookingReference = reference;
        }
        return ComplaintResponse.from(complaintRepository.save(
                new Complaint(user, bookingReference, request.subject().trim(), request.message().trim())));
    }

    @Transactional(readOnly = true)
    public List<ComplaintResponse> mine(Long userId) {
        return complaintRepository.findByUserIdOrderByCreatedAtDesc(userId).stream().map(ComplaintResponse::from).toList();
    }
}
