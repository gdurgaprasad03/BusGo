package com.example.busbooking.mail;

/** A plain-text email waiting to be sent. */
public record OutgoingEmail(String to, String subject, String body) {
}
