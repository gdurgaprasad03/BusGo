package com.example.busbooking;

import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import java.util.List;
import java.util.Map;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class BookingFlowTest extends IntegrationTestBase {

    @Test
    void bookingAvailableSeatsConfirmsAndReducesAvailability() throws Exception {
        String token = registerUser();
        JsonNode trip = firstKurnoolTrip();
        long tripId = trip.get("tripId").asLong();
        long before = availableSeats(tripId);
        List<String> seats = freeSeats(tripId).subList(0, 2);

        JsonNode booking = body(book(token, tripId, seats).andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("CONFIRMED"))
                .andExpect(jsonPath("$.passengers.length()").value(2)));

        assertTrue(booking.get("bookingReference").asText().matches("BG[A-Z0-9]{8}"));
        // Price is calculated by the server: fare x seats.
        assertEquals(trip.get("fare").asDouble() * 2, booking.get("totalAmount").asDouble(), 0.001);
        assertEquals(before - 2, availableSeats(tripId));
        assertTrue(booking.get("upcoming").asBoolean());
    }

    @Test
    void twoBookingsGetDifferentReferences() throws Exception {
        String token = registerUser();
        long tripId = firstKurnoolTrip().get("tripId").asLong();
        List<String> free = freeSeats(tripId);
        String r1 = body(book(token, tripId, free.subList(0, 1))).get("bookingReference").asText();
        String r2 = body(book(token, tripId, free.subList(1, 2))).get("bookingReference").asText();
        assertTrue(!r1.equals(r2));
    }

    @Test
    void alreadyBookedSeatIsRejectedAndNothingIsPartiallyBooked() throws Exception {
        String alice = registerUser();
        String bob = registerUser();
        long tripId = firstKurnoolTrip().get("tripId").asLong();
        List<String> free = freeSeats(tripId);
        String taken = free.get(0);
        String other = free.get(1);
        book(alice, tripId, List.of(taken)).andExpect(status().isCreated());
        long afterAlice = availableSeats(tripId);

        // Bob asks for the taken seat AND a free one: the whole request must fail.
        book(bob, tripId, List.of(other, taken)).andExpect(status().isConflict())
                .andExpect(jsonPath("$.message").value("Seat(s) no longer available: " + taken));

        assertEquals(afterAlice, availableSeats(tripId), "no seat may change on a rejected booking");
        assertTrue(freeSeats(tripId).contains(other), "the free seat must stay free");
        long bobBookings = body(mvc.perform(get("/api/bookings/my").header("Authorization", "Bearer " + bob))).size();
        assertEquals(0, bobBookings);
    }

    @Test
    void preSoldDemoSeatsCannotBeBooked() throws Exception {
        String token = registerUser();
        long tripId = firstKurnoolTrip().get("tripId").asLong();
        JsonNode seats = body(mvc.perform(get("/api/trips/" + tripId + "/seats"))).get("seats");
        String booked = null;
        for (JsonNode s : seats) {
            if (s.get("status").asText().equals("BOOKED")) { booked = s.get("seatNumber").asText(); break; }
        }
        assertTrue(booked != null, "seed data should contain pre-sold seats");
        book(token, tripId, List.of(booked)).andExpect(status().isConflict());
    }

    @Test
    void concurrentRequestsForTheSameSeatConfirmOnlyOne() throws Exception {
        String alice = registerUser();
        String bob = registerUser();
        long tripId = firstKurnoolTrip().get("tripId").asLong();
        String seat = freeSeats(tripId).get(0);

        ExecutorService pool = Executors.newFixedThreadPool(2);
        CountDownLatch start = new CountDownLatch(1);
        Callable<Integer> aliceCall = () -> { start.await(); return book(alice, tripId, List.of(seat)).andReturn().getResponse().getStatus(); };
        Callable<Integer> bobCall = () -> { start.await(); return book(bob, tripId, List.of(seat)).andReturn().getResponse().getStatus(); };
        Future<Integer> a = pool.submit(aliceCall);
        Future<Integer> b = pool.submit(bobCall);
        start.countDown();
        int s1 = a.get();
        int s2 = b.get();
        pool.shutdown();

        assertEquals(1, List.of(s1, s2).stream().filter(s -> s == 201).count(), "exactly one booking must succeed: " + s1 + "," + s2);
        assertEquals(1, List.of(s1, s2).stream().filter(s -> s == 409).count(), "the other must get 409: " + s1 + "," + s2);
        Integer confirmed = jdbc.queryForObject("SELECT COUNT(*) FROM booking_seats WHERE active_trip_seat_id IS NOT NULL", Integer.class);
        assertEquals(1, confirmed);
    }

    @Test
    void bookingEndpointsRequireLogin() throws Exception {
        mvc.perform(post("/api/bookings").contentType(MediaType.APPLICATION_JSON).content("{}")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/bookings/my")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/bookings/1")).andExpect(status().isUnauthorized());
    }

    @Test
    void usersCanOnlySeeAndCancelTheirOwnBookings() throws Exception {
        String alice = registerUser();
        String bob = registerUser();
        long tripId = firstKurnoolTrip().get("tripId").asLong();
        long bookingId = body(book(alice, tripId, freeSeats(tripId).subList(0, 1))).get("bookingId").asLong();

        mvc.perform(get("/api/bookings/" + bookingId).header("Authorization", "Bearer " + bob)).andExpect(status().isForbidden());
        cancel(bob, bookingId).andExpect(status().isForbidden());
        mvc.perform(get("/api/bookings/" + bookingId).header("Authorization", "Bearer " + alice)).andExpect(status().isOk());
        assertEquals(0, body(mvc.perform(get("/api/bookings/my").header("Authorization", "Bearer " + bob))).size());
        assertEquals(1, body(mvc.perform(get("/api/bookings/my").header("Authorization", "Bearer " + alice))).size());
        mvc.perform(get("/api/bookings/999999").header("Authorization", "Bearer " + alice)).andExpect(status().isNotFound());
    }

    @Test
    void cancellationRestoresSeatsOnlyOnceAndAllowsRebooking() throws Exception {
        String alice = registerUser();
        String bob = registerUser();
        long tripId = firstKurnoolTrip().get("tripId").asLong();
        long before = availableSeats(tripId);
        List<String> seats = freeSeats(tripId).subList(0, 3);
        long bookingId = body(book(alice, tripId, seats)).get("bookingId").asLong();
        assertEquals(before - 3, availableSeats(tripId));

        JsonNode cancelled = body(cancel(alice, bookingId).andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CANCELLED")).andExpect(jsonPath("$.upcoming").value(false)));
        assertTrue(cancelled.get("refundAmount").asDouble() <= cancelled.get("totalAmount").asDouble());
        assertTrue(cancelled.hasNonNull("cancelledAt"));
        assertEquals(before, availableSeats(tripId), "seats are restored");

        // A second cancel must be refused and must not release seats again (e.g. ones Bob took meanwhile).
        book(bob, tripId, seats.subList(0, 1)).andExpect(status().isCreated());
        cancel(alice, bookingId).andExpect(status().isConflict());
        assertEquals(before - 1, availableSeats(tripId), "double cancel must not free Bob's seat");
    }

    @Test
    void invalidBookingInputReturnsClearErrors() throws Exception {
        String token = registerUser();
        long tripId = firstKurnoolTrip().get("tripId").asLong();
        String seat = freeSeats(tripId).get(0);

        // No passengers
        mvc.perform(post("/api/bookings").header("Authorization", "Bearer " + token).contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("tripId", tripId, "passengers", List.of(),
                                "contactPhone", "9876543210", "contactEmail", "a@b.com", "paymentMethod", "UPI_DEMO"))))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.fieldErrors.passengers").exists());
        // Bad passenger data and contact phone
        mvc.perform(post("/api/bookings").header("Authorization", "Bearer " + token).contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("tripId", tripId,
                                "passengers", List.of(Map.of("seatNumber", seat, "name", "", "age", 0, "gender", "ROBOT")),
                                "contactPhone", "1", "contactEmail", "a@b.com", "paymentMethod", "UPI_DEMO"))))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.fieldErrors.contactPhone").exists());
        // Unknown payment method / malformed JSON
        mvc.perform(post("/api/bookings").header("Authorization", "Bearer " + token).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"tripId\": 1, \"paymentMethod\": \"BITCOIN\"}")).andExpect(status().isBadRequest());
        mvc.perform(post("/api/bookings").header("Authorization", "Bearer " + token).contentType(MediaType.APPLICATION_JSON)
                .content("not json")).andExpect(status().isBadRequest());
        // Unknown seat, duplicate seat, unknown trip
        book(token, tripId, List.of("99Z")).andExpect(status().isBadRequest());
        book(token, tripId, List.of(seat, seat)).andExpect(status().isBadRequest());
        book(token, 999999L, List.of(seat)).andExpect(status().isNotFound());
        assertEquals(0, body(mvc.perform(get("/api/bookings/my").header("Authorization", "Bearer " + token))).size());
    }

    @Test
    void moreThanSixSeatsInOneBookingIsRejected() throws Exception {
        String token = registerUser();
        long tripId = firstKurnoolTrip().get("tripId").asLong();
        book(token, tripId, freeSeats(tripId).subList(0, 7)).andExpect(status().isBadRequest());
    }
}
