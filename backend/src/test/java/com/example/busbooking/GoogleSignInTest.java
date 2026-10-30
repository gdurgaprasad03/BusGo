package com.example.busbooking;

import com.example.busbooking.exception.UnauthorizedException;
import com.example.busbooking.security.GoogleIdentity;
import com.example.busbooking.security.GoogleTokenVerifier;
import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.http.MediaType;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Google sign-in through the real controller, service and database, with a FAKE token verifier
 * (so no call to Google is made). The real verifier is tested in GoogleTokenInfoVerifierTest.
 */
class GoogleSignInTest extends IntegrationTestBase {

    @TestConfiguration
    static class FakeGoogle {
        @Bean
        @Primary
        GoogleTokenVerifier fakeGoogleVerifier() {
            Map<String, GoogleIdentity> tokens = Map.of(
                    "token-asha", new GoogleIdentity("google-sub-asha", "asha.google@example.com", "Asha Google"),
                    "token-no-name", new GoogleIdentity("google-sub-noname", "noname@example.com", ""),
                    "token-clash", new GoogleIdentity("google-sub-clash", "clash@example.com", "Someone Else"));
            return new GoogleTokenVerifier() {
                @Override public boolean isConfigured() { return true; }
                @Override public GoogleIdentity verify(String idToken) {
                    GoogleIdentity identity = tokens.get(idToken);
                    if (identity == null) throw new UnauthorizedException("Invalid Google sign-in token");
                    return identity;
                }
            };
        }
    }

    private JsonNode loginWithGoogle(String token) throws Exception {
        return body(mvc.perform(post("/api/auth/google").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("idToken", token)))).andExpect(status().isOk()));
    }

    @Test
    void configEndpointReportsGoogleAsEnabled() throws Exception {
        mvc.perform(get("/api/auth/config")).andExpect(status().isOk()).andExpect(jsonPath("$.googleEnabled").value(true));
    }

    @Test
    void firstGoogleSignInCreatesTheAccountAndReturnsAWorkingToken() throws Exception {
        JsonNode auth = loginWithGoogle("token-asha");
        assertEquals("asha.google@example.com", auth.get("user").get("email").asText());
        assertEquals("Asha Google", auth.get("user").get("fullName").asText());
        assertNull(auth.get("user").get("phone").textValue(), "a Google account has no phone until the user adds one");

        // The session token works on a protected endpoint.
        mvc.perform(get("/api/users/me").header("Authorization", "Bearer " + auth.get("token").asText()))
                .andExpect(status().isOk()).andExpect(jsonPath("$.email").value("asha.google@example.com"));
        assertEquals(1, jdbc.queryForObject("SELECT COUNT(*) FROM users WHERE google_sub = 'google-sub-asha'", Integer.class));
    }

    @Test
    void signingInAgainUsesTheSameAccount() throws Exception {
        long first = loginWithGoogle("token-asha").get("user").get("id").asLong();
        long second = loginWithGoogle("token-asha").get("user").get("id").asLong();
        assertEquals(first, second);
        assertEquals(1, jdbc.queryForObject("SELECT COUNT(*) FROM users", Integer.class));
    }

    @Test
    void aMissingNameFallsBackToTheEmailName() throws Exception {
        assertEquals("noname", loginWithGoogle("token-no-name").get("user").get("fullName").asText());
    }

    @Test
    void invalidTokensAreRejected() throws Exception {
        mvc.perform(post("/api/auth/google").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("idToken", "forged-token"))))
                .andExpect(status().isUnauthorized());
        mvc.perform(post("/api/auth/google").contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isBadRequest());
        mvc.perform(post("/api/auth/google").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("idToken", ""))))
                .andExpect(status().isBadRequest());
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM users", Integer.class));
    }

    @Test
    void anExistingPasswordAccountIsNeverTakenOverByGoogle() throws Exception {
        // Someone registered with this email and a password (the email was never verified).
        mvc.perform(post("/api/auth/register").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("fullName", "Registered First", "email", "clash@example.com",
                        "phone", "9876501234", "password", "Password123"))));

        mvc.perform(post("/api/auth/google").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("idToken", "token-clash"))))
                .andExpect(status().isConflict());
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM users WHERE google_sub IS NOT NULL", Integer.class),
                "the existing account must not be linked automatically");
        // The password account still works normally.
        mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("identifier", "clash@example.com", "password", "Password123"))))
                .andExpect(status().isOk());
    }

    @Test
    void aGoogleAccountCannotBeEnteredWithAGuessedPassword() throws Exception {
        loginWithGoogle("token-asha");
        mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("identifier", "asha.google@example.com", "password", "Password123"))))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void emailPasswordLoginStillWorks() throws Exception {
        registerUser(); // normal registration + the returned token
    }
}
