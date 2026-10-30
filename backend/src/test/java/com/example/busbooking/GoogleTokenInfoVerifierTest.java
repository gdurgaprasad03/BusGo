package com.example.busbooking;

import com.example.busbooking.exception.ServiceUnavailableException;
import com.example.busbooking.exception.UnauthorizedException;
import com.example.busbooking.security.GoogleIdentity;
import com.example.busbooking.security.GoogleTokenInfoVerifier;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Tests the real verifier against a small local server that imitates Google's tokeninfo endpoint,
 * so the checks (audience, issuer, expiry, verified email) run for real without calling Google.
 */
class GoogleTokenInfoVerifierTest {

    private static final String CLIENT_ID = "busgo-web.apps.googleusercontent.com";
    private static final long FUTURE = System.currentTimeMillis() / 1000 + 3600;
    private static final long PAST = System.currentTimeMillis() / 1000 - 3600;

    private HttpServer server;
    private String url;

    private static String claims(String aud, String iss, String emailVerified, long exp) {
        return "{\"aud\":\"" + aud + "\",\"iss\":\"" + iss + "\",\"sub\":\"1234567890\",\"email\":\"Person@Example.com\","
                + "\"email_verified\":\"" + emailVerified + "\",\"name\":\"Test Person\",\"exp\":\"" + exp + "\"}";
    }

    @BeforeEach
    void startFakeGoogle() throws Exception {
        Map<String, String> responses = Map.of(
                "good", claims(CLIENT_ID, "https://accounts.google.com", "true", FUTURE),
                "other-app", claims("someone-elses-app.apps.googleusercontent.com", "https://accounts.google.com", "true", FUTURE),
                "bad-issuer", claims(CLIENT_ID, "https://evil.example.com", "true", FUTURE),
                "unverified", claims(CLIENT_ID, "accounts.google.com", "false", FUTURE),
                "expired", claims(CLIENT_ID, "accounts.google.com", "true", PAST));
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/tokeninfo", exchange -> {
            String query = exchange.getRequestURI().getQuery();
            String token = query == null ? "" : query.replace("id_token=", "");
            String body = responses.get(token);
            byte[] bytes = (body == null ? "{\"error\":\"invalid_token\"}" : body).getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(body == null ? 400 : 200, bytes.length);
            exchange.getResponseBody().write(bytes);
            exchange.close();
        });
        server.start();
        url = "http://127.0.0.1:" + server.getAddress().getPort() + "/tokeninfo";
    }

    @AfterEach
    void stopFakeGoogle() {
        server.stop(0);
    }

    private GoogleTokenInfoVerifier verifier(String clientIds) {
        return new GoogleTokenInfoVerifier(new ObjectMapper(), clientIds, url);
    }

    @Test
    void aValidTokenReturnsTheVerifiedIdentity() {
        GoogleIdentity identity = verifier(CLIENT_ID).verify("good");
        assertEquals("1234567890", identity.subject());
        assertEquals("person@example.com", identity.email(), "email is normalised to lower case");
        assertEquals("Test Person", identity.name());
    }

    @Test
    void severalClientIdsCanBeConfigured() {
        assertEquals("1234567890", verifier("other.apps.googleusercontent.com, " + CLIENT_ID).verify("good").subject());
    }

    @Test
    void aTokenIssuedForAnotherAppIsRejected() {
        assertThrows(UnauthorizedException.class, () -> verifier(CLIENT_ID).verify("other-app"));
    }

    @Test
    void aWrongIssuerAnUnverifiedEmailAndAnExpiredTokenAreRejected() {
        assertThrows(UnauthorizedException.class, () -> verifier(CLIENT_ID).verify("bad-issuer"));
        assertThrows(UnauthorizedException.class, () -> verifier(CLIENT_ID).verify("unverified"));
        assertThrows(UnauthorizedException.class, () -> verifier(CLIENT_ID).verify("expired"));
    }

    @Test
    void anUnknownOrGarbageTokenIsRejected() {
        assertThrows(UnauthorizedException.class, () -> verifier(CLIENT_ID).verify("garbage"));
    }

    @Test
    void withoutAClientIdGoogleSignInIsReportedAsNotConfigured() {
        GoogleTokenInfoVerifier notConfigured = verifier("");
        assertFalse(notConfigured.isConfigured());
        assertThrows(ServiceUnavailableException.class, () -> notConfigured.verify("good"));
        assertTrue(verifier(CLIENT_ID).isConfigured());
    }

    @Test
    void anUnreachableGoogleIsAServiceProblemNotALogin() {
        GoogleTokenInfoVerifier unreachable = new GoogleTokenInfoVerifier(new ObjectMapper(), CLIENT_ID, "http://127.0.0.1:1/tokeninfo");
        assertThrows(ServiceUnavailableException.class, () -> unreachable.verify("good"));
    }
}
