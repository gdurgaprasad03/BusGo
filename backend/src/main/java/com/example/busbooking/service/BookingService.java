package com.example.busbooking.service;

import com.example.busbooking.dto.BookingRequest;
import com.example.busbooking.dto.BookingResponse;
import com.example.busbooking.dto.PassengerRequest;
import com.example.busbooking.entity.Booking;
import com.example.busbooking.entity.BookingSeat;
import com.example.busbooking.entity.BookingStatus;
import com.example.busbooking.entity.SeatStatus;
import com.example.busbooking.entity.Trip;
import com.example.busbooking.entity.TripSeat;
import com.example.busbooking.entity.User;
import com.example.busbooking.exception.BadRequestException;
import com.example.busbooking.exception.ConflictException;
import com.example.busbooking.exception.ForbiddenException;
import com.example.busbooking.exception.ResourceNotFoundException;
import com.example.busbooking.exception.SeatUnavailableException;
import com.example.busbooking.mail.EmailTemplates;
import com.example.busbooking.mail.Mailer;
import com.example.busbooking.repository.BookingRepository;
import com.example.busbooking.repository.TripRepository;
import com.example.busbooking.repository.TripSeatRepository;
import com.example.busbooking.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * The heart of the app. Both create() and cancel() run in ONE database transaction:
 * either every change is saved, or (on any exception) none of them is.
 */
@Service
public class BookingService {

    private static final String REFERENCE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // no look-alike 0/O/1/I
    private final SecureRandom random = new SecureRandom();

    private final BookingRepository bookingRepository;
    private final TripRepository tripRepository;
    private final TripSeatRepository tripSeatRepository;
    private final UserRepository userRepository;
    private final Mailer mailer;

    public BookingService(BookingRepository bookingRepository, TripRepository tripRepository,
                          TripSeatRepository tripSeatRepository, UserRepository userRepository, Mailer mailer) {
        this.bookingRepository = bookingRepository;
        this.tripRepository = tripRepository;
        this.tripSeatRepository = tripSeatRepository;
        this.userRepository = userRepository;
        this.mailer = mailer;
    }

    @Transactional
    public BookingResponse createBooking(Long userId, BookingRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
        Trip trip = tripRepository.findDetailedById(request.tripId())
                .orElseThrow(() -> new ResourceNotFoundException("Trip " + request.tripId() + " not found"));
        LocalDateTime now = LocalDateTime.now();
        if (!trip.getDepartureTime().isAfter(now)) {
            throw new BadRequestException("This bus has already departed");
        }

        List<PassengerRequest> passengers = request.passengers();
        List<String> seatNumbers = passengers.stream().map(p -> p.seatNumber().trim().toUpperCase()).toList();
        Set<String> unique = new HashSet<>(seatNumbers);
        if (unique.size() != seatNumbers.size()) {
            throw new BadRequestException("The same seat was selected more than once");
        }

        // Step 1: lock the seat rows (SELECT ... FOR UPDATE). Competing requests wait here.
        Map<String, TripSeat> seatsByNumber = tripSeatRepository.lockSeats(trip.getId(), unique).stream()
                .collect(Collectors.toMap(TripSeat::getSeatNumber, Function.identity()));
        if (seatsByNumber.size() != unique.size()) {
            List<String> unknown = seatNumbers.stream().filter(n -> !seatsByNumber.containsKey(n)).toList();
            throw new BadRequestException("Unknown seat(s) for this trip: " + String.join(", ", unknown));
        }

        // Step 2: re-check availability while holding the lock. All-or-nothing: one bad seat rejects all.
        List<String> taken = seatNumbers.stream()
                .filter(n -> seatsByNumber.get(n).getStatus() != SeatStatus.AVAILABLE).toList();
        if (!taken.isEmpty()) {
            throw new SeatUnavailableException(taken);
        }

        // Step 3: the server (not the app) decides the price.
        BigDecimal total = trip.getFare().multiply(BigDecimal.valueOf(seatNumbers.size()));

        Booking booking = new Booking(newReference(), user, trip, total,
                request.contactPhone(), request.contactEmail().trim(), request.paymentMethod());
        for (int i = 0; i < passengers.size(); i++) {
            PassengerRequest p = passengers.get(i);
            TripSeat seat = seatsByNumber.get(seatNumbers.get(i));
            seat.setStatus(SeatStatus.BOOKED);
            booking.addSeat(new BookingSeat(booking, seat, p.name().trim(), p.age(), p.gender()));
        }
        bookingRepository.saveAndFlush(booking); // flush now so constraint problems surface inside the transaction
        BookingResponse response = BookingResponse.from(booking, now);
        // Sent only after this transaction commits, so a rolled-back booking never produces a confirmation email.
        mailer.queue(EmailTemplates.bookingConfirmed(booking.getContactEmail(), response));
        return response;
    }

    @Transactional(readOnly = true)
    public List<BookingResponse> myBookings(Long userId) {
        LocalDateTime now = LocalDateTime.now();
        return bookingRepository.findByUserIdOrderByCreatedAtDesc(userId).stream()
                .map(b -> BookingResponse.from(b, now)).toList();
    }

    @Transactional(readOnly = true)
    public BookingResponse getBooking(Long userId, Long bookingId) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking " + bookingId + " not found"));
        assertOwner(booking, userId);
        return BookingResponse.from(booking, LocalDateTime.now());
    }

    @Transactional
    public BookingResponse cancelBooking(Long userId, Long bookingId) {
        // Lock the booking row so two simultaneous cancellations cannot both release the seats.
        Booking booking = bookingRepository.findByIdForUpdate(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking " + bookingId + " not found"));
        assertOwner(booking, userId);
        if (booking.getStatus() == BookingStatus.CANCELLED) {
            throw new ConflictException("This booking is already cancelled");
        }
        LocalDateTime now = LocalDateTime.now();
        if (!booking.getTrip().getDepartureTime().isAfter(now)) {
            throw new BadRequestException("This bus has already departed and cannot be cancelled");
        }

        BigDecimal refund = CancellationPolicy.refundFor(booking.getTotalAmount(), booking.getTrip().getDepartureTime(), now);
        for (BookingSeat bs : booking.getSeats()) {
            bs.getTripSeat().setStatus(SeatStatus.AVAILABLE); // restore seat inventory
            bs.release();                                       // frees the unique "active seat" slot
        }
        booking.markCancelled(refund);
        bookingRepository.saveAndFlush(booking);
        BookingResponse response = BookingResponse.from(booking, now);
        mailer.queue(EmailTemplates.bookingCancelled(booking.getContactEmail(), response));
        return response;
    }

    private void assertOwner(Booking booking, Long userId) {
        if (!booking.getUser().getId().equals(userId)) {
            throw new ForbiddenException("You do not have access to this booking");
        }
    }

    private String newReference() {
        for (int attempt = 0; attempt < 10; attempt++) {
            StringBuilder sb = new StringBuilder("BG");
            for (int i = 0; i < 8; i++) {
                sb.append(REFERENCE_CHARS.charAt(random.nextInt(REFERENCE_CHARS.length())));
            }
            if (!bookingRepository.existsByReference(sb.toString())) {
                return sb.toString();
            }
        }
        throw new IllegalStateException("Could not generate a unique booking reference");
    }
}
