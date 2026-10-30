package com.example.busbooking.mail;

/**
 * Sends email. Two implementations exist: {@link SmtpMailService} (real SMTP, when app.mail.enabled=true) and
 * {@link LoggingMailService} (nothing is sent; used when email is not configured).
 * Sending must never make a request fail, so implementations log problems instead of throwing.
 */
public interface MailService {

    void send(OutgoingEmail email);

    /** True when messages really leave the server (SMTP configured). */
    boolean isDeliveryEnabled();
}
