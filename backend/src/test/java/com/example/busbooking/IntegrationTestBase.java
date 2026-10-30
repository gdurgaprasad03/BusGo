package com.example.busbooking;

import com.example.busbooking.service.DemoDataService;
import com.fasterxml.jackson.databind.JsonNode;
import com.icegreen.greenmail.util.GreenMail;
import com.icegreen.greenmail.util.ServerSetupTest;
import jakarta.mail.internet.MimeMessage;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

/** Shared setup: full Spring context + H2 database, with fresh demo data before every test. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
abstract class IntegrationTestBase {

    /**
     * A real SMTP server inside the test JVM. The app sends its emails to it exactly like it would to Gmail, so tests
     * can read what was delivered. One shared instance; the port is chosen freely and handed to Spring below.
     */
    protected static final GreenMail greenMail = new GreenMail(ServerSetupTest.SMTP.dynamicPort());

    static {
        greenMail.start();
    }

    @DynamicPropertySource
    static void mailProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.mail.port", () -> greenMail.getSmtp().getPort());
    }

    /** Waits for the background mail thread and returns the messages that arrived (newest last). */
    protected MimeMessage[] receivedEmails(int expectedCount) {
        greenMail.waitForIncomingEmail(5000, expectedCount);
        return greenMail.getReceivedMessages();
    }

    /** The plain-text body of a delivered message. */
    protected static String bodyOf(MimeMessage message) throws Exception {
        return String.valueOf(message.getContent());
    }

    @Autowired protected MockMvc mvc;
    @Autowired protected ObjectMapper json;
    @Autowired protected DemoDataService demoDataService;
    @Autowired protected JdbcTemplate jdbc;

    protected final LocalDate tomorrow = LocalDate.now().plusDays(1);

    @BeforeEach
    void resetDemoData() throws Exception {
        greenMail.purgeEmailFromAllMailboxes(); // every test starts with an empty inbox
        demoDataService.reset();
        // reset() keeps users, but tests want a clean slate. Delete rows that reference users first.
        jdbc.update("DELETE FROM password_reset_codes");
        jdbc.update("DELETE FROM complaints");
        jdbc.update("DELETE FROM saved_passengers");
        jdbc.update("DELETE FROM users");
    }

    protected JsonNode body(ResultActions result) throws Exception {
        return json.readTree(result.andReturn().getResponse().getContentAsString());
    }

    /** Registers a unique user and returns its JWT. */
    protected String registerUser() throws Exception {
        String email = "user-" + UUID.randomUUID().toString().substring(0, 8) + "@example.com";
        return body(mvc.perform(post("/api/auth/register").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of(
                        "fullName", "Test User", "email", email, "phone", "9876543210", "password", "Password123")))))
                .get("token").asText();
    }

    protected JsonNode search(String source, String destination, String extraQuery) throws Exception {
        return body(mvc.perform(get("/api/trips/search?source=" + source + "&destination=" + destination
                + "&date=" + tomorrow + extraQuery)));
    }

    /** First search result for Kurnool -> Hyderabad tomorrow (06:30 AC seater, plenty of seats). */
    protected JsonNode firstKurnoolTrip() throws Exception {
        return search("Kurnool", "Hyderabad", "").get(0);
    }

    protected Map<String, Object> bookingBody(long tripId, List<String> seats) {
        List<Map<String, Object>> passengers = seats.stream().<Map<String, Object>>map(s -> Map.of(
                "seatNumber", s, "name", "Passenger " + s, "age", 30, "gender", "MALE")).toList();
        return Map.of("tripId", tripId, "passengers", passengers, "contactPhone", "9876543210",
                "contactEmail", "contact@example.com", "paymentMethod", "UPI_DEMO");
    }

    protected ResultActions book(String token, long tripId, List<String> seats) throws Exception {
        return mvc.perform(post("/api/bookings").header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(bookingBody(tripId, seats))));
    }

    protected ResultActions cancel(String token, long bookingId) throws Exception {
        return mvc.perform(patch("/api/bookings/" + bookingId + "/cancel").header("Authorization", "Bearer " + token));
    }

    protected long availableSeats(long tripId) throws Exception {
        return body(mvc.perform(get("/api/trips/" + tripId))).get("availableSeats").asLong();
    }

    /** Seat numbers currently AVAILABLE on a trip (read through the real API). */
    protected List<String> freeSeats(long tripId) throws Exception {
        JsonNode seats = body(mvc.perform(get("/api/trips/" + tripId + "/seats"))).get("seats");
        List<String> free = new java.util.ArrayList<>();
        seats.forEach(s -> { if (s.get("status").asText().equals("AVAILABLE")) free.add(s.get("seatNumber").asText()); });
        return free;
    }
}
