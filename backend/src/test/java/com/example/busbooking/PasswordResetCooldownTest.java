package com.example.busbooking;

import jakarta.mail.Address;
import jakarta.mail.Message;
import jakarta.mail.internet.MimeMessage;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Asking for codes again and again must not flood someone's inbox. */
@TestPropertySource(properties = "app.password-reset.resend-seconds=60")
class PasswordResetCooldownTest extends IntegrationTestBase {

    @Test
    void asecondRequestWithinTheCooldownDoesNotSendAnotherCode() throws Exception {
        mvc.perform(post("/api/auth/register").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("fullName", "Flood Test", "email", "flood@example.com",
                        "phone", "9876500010", "password", "Password123")))).andExpect(status().isCreated());

        for (int i = 0; i < 4; i++) {
            mvc.perform(post("/api/auth/forgot-password").contentType(MediaType.APPLICATION_JSON)
                    .content(json.writeValueAsString(Map.of("email", "flood@example.com")))).andExpect(status().isOk());
        }
        Thread.sleep(1500); // let the mail thread finish
        int codeMails = 0;
        for (MimeMessage m : greenMail.getReceivedMessages()) {
            for (Address a : m.getRecipients(Message.RecipientType.TO)) {
                if (a.toString().equals("flood@example.com") && m.getSubject().contains("reset code")) codeMails++;
            }
        }
        assertEquals(1, codeMails, "four requests in a row must produce only one code email");
    }
}
