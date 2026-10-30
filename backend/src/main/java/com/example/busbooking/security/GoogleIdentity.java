package com.example.busbooking.security;

/** A person whose Google ID token was verified. Only built from a token Google confirmed; never from client input. */
public record GoogleIdentity(String subject, String email, String name) {
}
