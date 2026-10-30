package com.example.busbooking;

import jakarta.mail.Address;
import jakarta.mail.Message;
import jakarta.mail.internet.MimeMessage;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Emails are really sent over SMTP (to a GreenMail server inside the test) and the forgot-password flow works
 * end to end with the code that arrives in the inbox.
 */
class EmailAndPasswordResetTest extends IntegrationTestBase {

    private static final Pattern CODE = Pattern.compile("(?m)^\\s+(\\d{6})\\s*$");

    /** Waits (up to 6 s) until at least {@code expected} emails to {@code address} arrived, then returns all of them. */
    private List<MimeMessage> mailsTo(String address, int expected) throws Exception {
        long deadline = System.currentTimeMillis() + 6000;
        List<MimeMessage> found;
        do {
            found = new ArrayList<>();
            for (MimeMessage m : greenMail.getReceivedMessages()) {
                for (Address a : m.getRecipients(Message.RecipientType.TO)) {
                    if (a.toString().equalsIgnoreCase(address)) found.add(m);
                }
            }
            if (found.size() >= expected) return found;
            Thread.sleep(100);
        } while (System.currentTimeMillis() < deadline);
        return found;
    }

    private void register(String email, String phone, String password) throws Exception {
        mvc.perform(post("/api/auth/register").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("fullName", "Asha Rao", "email", email, "phone", phone, "password", password))))
                .andExpect(status().isCreated());
    }

    private void forgot(String email) throws Exception {
        mvc.perform(post("/api/auth/forgot-password").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("email", email)))).andExpect(status().isOk());
    }

    private int reset(String email, String code, String newPassword) throws Exception {
        return mvc.perform(post("/api/auth/reset-password").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("email", email, "code", code, "newPassword", newPassword))))
                .andReturn().getResponse().getStatus();
    }

    private int login(String identifier, String password) throws Exception {
        return mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("identifier", identifier, "password", password))))
                .andReturn().getResponse().getStatus();
    }

    private String codeFrom(MimeMessage message) throws Exception {
        Matcher m = CODE.matcher(bodyOf(message));
        assertTrue(m.find(), "the email must contain a 6-digit code on its own line");
        return m.group(1);
    }

    private String wrongCodeFor(String realCode) {
        return realCode.equals("000000") ? "000001" : "000000";
    }

    @Test
    void registrationSendsAWelcomeEmail() throws Exception {
        register("welcome@example.com", "9876500001", "Password123");
        List<MimeMessage> mails = mailsTo("welcome@example.com", 1);
        assertEquals(1, mails.size());
        assertEquals("Welcome to BusGo", mails.get(0).getSubject());
        assertTrue(bodyOf(mails.get(0)).contains("Asha Rao"));
        assertTrue(mails.get(0).getFrom()[0].toString().contains("no-reply@busgo.test"));
    }

    @Test
    void forgotPasswordEmailsACodeAndTheCodeResetsThePassword() throws Exception {
        register("reset1@example.com", "9876500002", "OldPassword1");
        forgot("reset1@example.com");

        List<MimeMessage> mails = mailsTo("reset1@example.com", 2); // welcome + code
        MimeMessage codeMail = mails.stream().filter(m -> {
            try { return m.getSubject().contains("reset code"); } catch (Exception e) { return false; }
        }).findFirst().orElseThrow(() -> new AssertionError("no reset email arrived"));
        String code = codeFrom(codeMail);

        assertEquals(200, reset("reset1@example.com", code, "NewPassword9"));
        assertEquals(401, login("reset1@example.com", "OldPassword1"), "the old password must stop working");
        assertEquals(200, login("reset1@example.com", "NewPassword9"));
        assertEquals(200, login("9876500002", "NewPassword9"), "mobile login uses the new password too");

        // A "your password was changed" notice follows.
        assertTrue(mailsTo("reset1@example.com", 3).stream().anyMatch(m -> {
            try { return m.getSubject().contains("password was changed"); } catch (Exception e) { return false; }
        }));

        // The code works only once.
        assertEquals(400, reset("reset1@example.com", code, "AnotherPass77"));
        assertEquals(200, login("reset1@example.com", "NewPassword9"));
    }

    @Test
    void wrongCodesAreRejectedAndTooManyGuessesLockTheCode() throws Exception {
        register("lock@example.com", "9876500003", "OldPassword1");
        forgot("lock@example.com");
        String code = codeFrom(mailsTo("lock@example.com", 2).stream()
                .filter(m -> { try { return m.getSubject().contains("reset code"); } catch (Exception e) { return false; } })
                .findFirst().orElseThrow());
        String wrong = wrongCodeFor(code);

        for (int i = 0; i < 5; i++) {
            assertEquals(400, reset("lock@example.com", wrong, "NewPassword9"));
        }
        // After 5 wrong guesses even the correct code is refused.
        assertEquals(400, reset("lock@example.com", code, "NewPassword9"));
        assertEquals(200, login("lock@example.com", "OldPassword1"), "the password never changed");
    }

    @Test
    void anUnknownEmailGetsTheSameAnswerAndNoEmailIsSent() throws Exception {
        register("known@example.com", "9876500004", "Password123");
        String known = mvc.perform(post("/api/auth/forgot-password").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("email", "known@example.com"))))
                .andReturn().getResponse().getContentAsString();
        String unknown = mvc.perform(post("/api/auth/forgot-password").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("email", "nobody@example.com"))))
                .andReturn().getResponse().getContentAsString();

        assertEquals(known, unknown, "the response must not reveal whether the email is registered");
        Thread.sleep(800); // give a wrongly sent mail time to arrive
        assertTrue(mailsTo("nobody@example.com", 1).isEmpty(), "nothing may be sent to an address with no account");
    }

    @Test
    void aNewCodeReplacesTheOldOne() throws Exception {
        register("again@example.com", "9876500005", "OldPassword1");
        forgot("again@example.com");
        String first = codeFrom(mailsTo("again@example.com", 2).stream()
                .filter(m -> { try { return m.getSubject().contains("reset code"); } catch (Exception e) { return false; } })
                .findFirst().orElseThrow());
        forgot("again@example.com");
        List<MimeMessage> codeMails = mailsTo("again@example.com", 3).stream()
                .filter(m -> { try { return m.getSubject().contains("reset code"); } catch (Exception e) { return false; } }).toList();
        assertEquals(2, codeMails.size());
        String second = null;
        for (MimeMessage m : codeMails) {
            String c = codeFrom(m);
            if (!c.equals(first)) second = c;
        }
        if (second == null) { // both codes happened to be identical (1 in a million): nothing to compare
            return;
        }
        assertEquals(400, reset("again@example.com", first, "NewPassword9"), "the old code must no longer work");
        assertEquals(200, reset("again@example.com", second, "NewPassword9"));
    }

    @Test
    void anExpiredCodeIsRejected() throws Exception {
        register("expired@example.com", "9876500006", "OldPassword1");
        forgot("expired@example.com");
        String code = codeFrom(mailsTo("expired@example.com", 2).stream()
                .filter(m -> { try { return m.getSubject().contains("reset code"); } catch (Exception e) { return false; } })
                .findFirst().orElseThrow());
        jdbc.update("UPDATE password_reset_codes SET expires_at = ?", LocalDateTime.now().minusMinutes(1));
        assertEquals(400, reset("expired@example.com", code, "NewPassword9"));
        assertEquals(200, login("expired@example.com", "OldPassword1"));
    }

    @Test
    void theCodeIsStoredOnlyAsAHash() throws Exception {
        register("hash@example.com", "9876500007", "Password123");
        forgot("hash@example.com");
        String code = codeFrom(mailsTo("hash@example.com", 2).stream()
                .filter(m -> { try { return m.getSubject().contains("reset code"); } catch (Exception e) { return false; } })
                .findFirst().orElseThrow());
        String stored = jdbc.queryForObject("SELECT code_hash FROM password_reset_codes", String.class);
        assertTrue(stored.startsWith("$2"), "BCrypt hash expected");
        assertFalse(stored.contains(code));
    }

    @Test
    void invalidInputIsRejected() throws Exception {
        mvc.perform(post("/api/auth/forgot-password").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("email", "not-an-email")))).andExpect(status().isBadRequest());
        mvc.perform(post("/api/auth/reset-password").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("email", "a@b.com", "code", "12", "newPassword", "NewPassword9"))))
                .andExpect(status().isBadRequest());
        mvc.perform(post("/api/auth/reset-password").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("email", "a@b.com", "code", "123456", "newPassword", "short"))))
                .andExpect(status().isBadRequest());
    }

    @Test
    void bookingAndCancellationSendEmails() throws Exception {
        String token = registerUser();
        long tripId = firstKurnoolTrip().get("tripId").asLong();
        String reference = body(book(token, tripId, freeSeats(tripId).subList(0, 2))).get("bookingReference").asText();
        long bookingId = jdbc.queryForObject("SELECT id FROM bookings WHERE reference = ?", Long.class, reference);

        List<MimeMessage> mails = mailsTo("contact@example.com", 1); // bookingBody() uses this contact email
        MimeMessage confirmed = mails.stream().filter(m -> {
            try { return m.getSubject().contains(reference); } catch (Exception e) { return false; }
        }).findFirst().orElseThrow(() -> new AssertionError("no booking confirmation email"));
        assertTrue(confirmed.getSubject().contains("confirmed"));
        String text = bodyOf(confirmed);
        assertTrue(text.contains("Kurnool to Hyderabad"));
        assertTrue(text.contains("Passenger"));
        assertTrue(text.contains("DEMO"), "demo bookings must say they are not valid for travel");

        cancel(token, bookingId).andExpect(status().isOk());
        assertTrue(mailsTo("contact@example.com", 2).stream().anyMatch(m -> {
            try { return m.getSubject().contains("cancelled") && m.getSubject().contains(reference); } catch (Exception e) { return false; }
        }), "a cancellation email must arrive");
    }

    @Test
    void aRejectedBookingSendsNoEmail() throws Exception {
        String token = registerUser();
        long tripId = firstKurnoolTrip().get("tripId").asLong();
        book(token, tripId, List.of("99Z")).andExpect(status().isBadRequest());
        Thread.sleep(600);
        assertTrue(mailsTo("contact@example.com", 1).isEmpty(), "no confirmation for a booking that failed");
    }

    @Test
    void authConfigReportsThatEmailIsEnabled() throws Exception {
        mvc.perform(get("/api/auth/config")).andExpect(status().isOk()).andExpect(jsonPath("$.emailEnabled").value(true));
        assertNotEquals(0, greenMail.getSmtp().getPort());
    }
}
