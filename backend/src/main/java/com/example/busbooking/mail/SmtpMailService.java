package com.example.busbooking.mail;

import jakarta.annotation.PreDestroy;
import jakarta.mail.internet.MimeMessage;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Sends real email through the SMTP server configured with spring.mail.* (see docs/EMAIL_SETUP.md).
 * Messages are sent on a background thread so a slow mail server never slows an API request, and a failure is logged
 * (without the message body or any secret) instead of breaking the request.
 */
@Service
@ConditionalOnProperty(name = "app.mail.enabled", havingValue = "true")
public class SmtpMailService implements MailService {

    private static final Logger log = LoggerFactory.getLogger(SmtpMailService.class);

    private final JavaMailSender mailSender;
    private final String from;
    private final ExecutorService executor = Executors.newSingleThreadExecutor(r -> {
        Thread t = new Thread(r, "mail-sender");
        t.setDaemon(true);
        return t;
    });

    public SmtpMailService(JavaMailSender mailSender, @Value("${app.mail.from:}") String from,
                           @Value("${spring.mail.username:}") String username) {
        this.mailSender = mailSender;
        // "BusGo <address>" if a from address is configured, otherwise the SMTP login (works for Gmail).
        this.from = !from.isBlank() ? from : username;
        if (this.from.isBlank()) {
            throw new IllegalStateException(
                    "app.mail.enabled is true but neither MAIL_FROM nor MAIL_USERNAME is set. See docs/EMAIL_SETUP.md.");
        }
    }

    @Override
    public boolean isDeliveryEnabled() {
        return true;
    }

    @Override
    public void send(OutgoingEmail email) {
        executor.submit(() -> deliver(email));
    }

    private void deliver(OutgoingEmail email) {
        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, false, StandardCharsets.UTF_8.name());
            helper.setFrom(from);
            helper.setTo(email.to());
            helper.setSubject(email.subject().replaceAll("[\\r\\n]+", " ")); // no header injection
            helper.setText(email.body(), false);
            mailSender.send(message);
            log.info("Email sent to {}", mask(email.to()));
        } catch (Exception e) {
            // The exception type only: messages can contain server names or credentials.
            log.warn("Could not send email to {}: {}", mask(email.to()), e.getClass().getSimpleName());
        }
    }

    @PreDestroy
    void stop() {
        executor.shutdown();
    }

    /** a***@example.com: logs never contain a full address. */
    static String mask(String address) {
        int at = address.indexOf('@');
        return at <= 1 ? "***" : address.charAt(0) + "***" + address.substring(at);
    }
}
