package com.example.busbooking.security;

/** Checks a Google ID token. An interface so tests can use a fake instead of calling Google. */
public interface GoogleTokenVerifier {

    /** True when at least one Google OAuth client id is configured (env GOOGLE_CLIENT_IDS). */
    boolean isConfigured();

    /**
     * Verifies the token with Google and returns the identity inside it.
     *
     * @throws com.example.busbooking.exception.ServiceUnavailableException if Google sign-in is not configured
     * @throws com.example.busbooking.exception.UnauthorizedException        if the token is invalid, expired,
     *         meant for another app, or the email is not verified
     */
    GoogleIdentity verify(String idToken);
}
