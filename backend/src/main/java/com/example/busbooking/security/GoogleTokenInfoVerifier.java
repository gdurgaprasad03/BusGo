package com.example.busbooking.security;

import com.example.busbooking.exception.ServiceUnavailableException;
import com.example.busbooking.exception.UnauthorizedException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Arrays;
import java.util.List;
import java.util.Set;

/**
 * Verifies a Google ID token by asking Google's own "tokeninfo" endpoint. Google checks the signature and the
 * expiry; we then check that the token was issued for OUR app (the audience), that the issuer is Google, and that
 * Google has verified the email address. A token meant for some other app is rejected.
 */
@Component
public class GoogleTokenInfoVerifier implements GoogleTokenVerifier {

    private static final Logger log = LoggerFactory.getLogger(GoogleTokenInfoVerifier.class);
    private static final Set<String> ISSUERS = Set.of("accounts.google.com", "https://accounts.google.com");

    private final ObjectMapper objectMapper;
    private final List<String> clientIds;
    private final String tokenInfoUrl;
    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build();

    public GoogleTokenInfoVerifier(ObjectMapper objectMapper,
                                   @Value("${app.google.client-ids:}") String clientIds,
                                   @Value("${app.google.tokeninfo-url:https://oauth2.googleapis.com/tokeninfo}") String tokenInfoUrl) {
        this.objectMapper = objectMapper;
        this.clientIds = Arrays.stream(clientIds.split(",")).map(String::trim).filter(s -> !s.isEmpty()).toList();
        this.tokenInfoUrl = tokenInfoUrl;
    }

    @Override
    public boolean isConfigured() {
        return !clientIds.isEmpty();
    }

    @Override
    public GoogleIdentity verify(String idToken) {
        if (!isConfigured()) {
            throw new ServiceUnavailableException(
                    "Google sign-in is not configured on the server. Set GOOGLE_CLIENT_IDS (see docs/GOOGLE_SIGN_IN_SETUP.md).");
        }
        JsonNode claims = fetchClaims(idToken);

        String audience = text(claims, "aud");
        if (!clientIds.contains(audience)) {
            throw new UnauthorizedException("This Google token was not issued for BusGo");
        }
        if (!ISSUERS.contains(text(claims, "iss"))) {
            throw new UnauthorizedException("Invalid Google sign-in token");
        }
        if (claims.path("exp").asLong(0) * 1000 < System.currentTimeMillis()) {
            throw new UnauthorizedException("Your Google sign-in has expired. Please try again.");
        }
        if (!"true".equalsIgnoreCase(text(claims, "email_verified"))) {
            throw new UnauthorizedException("Your Google email address is not verified");
        }
        String subject = text(claims, "sub");
        String email = text(claims, "email");
        if (subject.isEmpty() || email.isEmpty()) {
            throw new UnauthorizedException("Invalid Google sign-in token");
        }
        return new GoogleIdentity(subject, email.toLowerCase(), text(claims, "name"));
    }

    private JsonNode fetchClaims(String idToken) {
        try {
            HttpRequest request = HttpRequest.newBuilder(
                            URI.create(tokenInfoUrl + "?id_token=" + URLEncoder.encode(idToken, StandardCharsets.UTF_8)))
                    .timeout(Duration.ofSeconds(5)).GET().build();
            HttpResponse<String> response = http.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() != 200) {
                throw new UnauthorizedException("Invalid Google sign-in token");
            }
            return objectMapper.readTree(response.body());
        } catch (UnauthorizedException e) {
            throw e;
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new ServiceUnavailableException("Could not reach Google to verify the sign-in. Please try again.");
        } catch (Exception e) {
            // The exception type only: the message can contain the request URL.
            log.warn("Google token verification failed: {}", e.getClass().getSimpleName());
            throw new ServiceUnavailableException("Could not reach Google to verify the sign-in. Please try again.");
        }
    }

    private static String text(JsonNode node, String field) {
        return node.path(field).asText("");
    }
}
