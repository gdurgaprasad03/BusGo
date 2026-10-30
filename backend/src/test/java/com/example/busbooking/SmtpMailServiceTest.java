package com.example.busbooking;

import com.example.busbooking.mail.LoggingMailService;
import com.example.busbooking.mail.OutgoingEmail;
import com.example.busbooking.mail.SmtpMailService;
import org.junit.jupiter.api.Test;
import org.springframework.mail.javamail.JavaMailSenderImpl;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** Plain unit tests (no Spring): a broken mail server must never break the app, and mail needs a sender address. */
class SmtpMailServiceTest {

    @Test
    void anUnreachableMailServerDoesNotThrowIntoTheCaller() throws Exception {
        JavaMailSenderImpl sender = new JavaMailSenderImpl();
        sender.setHost("127.0.0.1");
        sender.setPort(1); // nothing listens here
        sender.getJavaMailProperties().put("mail.smtp.connectiontimeout", "500");
        sender.getJavaMailProperties().put("mail.smtp.timeout", "500");
        SmtpMailService service = new SmtpMailService(sender, "BusGo <no-reply@busgo.test>", "");
        assertTrue(service.isDeliveryEnabled());
        assertDoesNotThrow(() -> service.send(new OutgoingEmail("someone@example.com", "Test", "Body")));
        Thread.sleep(1200); // the failure happens on the background thread and is only logged
    }

    @Test
    void enablingMailWithoutAnySenderAddressFailsAtStartupWithAClearMessage() {
        IllegalStateException e = assertThrows(IllegalStateException.class,
                () -> new SmtpMailService(new JavaMailSenderImpl(), "", ""));
        assertTrue(e.getMessage().contains("MAIL_FROM"));
    }

    @Test
    void theLoggingFallbackDeliversNothing() {
        LoggingMailService service = new LoggingMailService(false);
        assertFalse(service.isDeliveryEnabled());
        assertDoesNotThrow(() -> service.send(new OutgoingEmail("someone@example.com", "Test", "secret body")));
    }
}
