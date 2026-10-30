package com.example.busbooking;

import com.example.busbooking.mail.BrevoMailService;
import com.example.busbooking.mail.OutgoingEmail;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Plain unit tests: the Brevo HTTPS sender talks to a local stand-in for Brevo's API, so we can check exactly what would be
 * sent (URL, method, API key header, JSON fields) without an account or any network.
 */
class BrevoMailServiceTest {

    private record Captured(String method, String apiKey, String contentType, String body) {}

    private HttpServer server;
    private String url;
    private final BlockingQueue<Captured> requests = new LinkedBlockingQueue<>();
    private volatile int responseStatus = 201;

    @BeforeEach
    void startFakeBrevo() throws Exception {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/v3/smtp/email", exchange -> {
            String body = new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8);
            requests.add(new Captured(exchange.getRequestMethod(), exchange.getRequestHeaders().getFirst("api-key"),
                    exchange.getRequestHeaders().getFirst("content-type"), body));
            byte[] reply = "{\"messageId\":\"<1@test>\"}".getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(responseStatus, reply.length);
            exchange.getResponseBody().write(reply);
            exchange.close();
        });
        server.start();
        url = "http://127.0.0.1:" + server.getAddress().getPort() + "/v3/smtp/email";
    }

    @AfterEach
    void stopFakeBrevo() {
        server.stop(0);
    }

    private BrevoMailService service(String from) {
        return new BrevoMailService(new ObjectMapper(), "test-api-key-123", url, from);
    }

    @Test
    void sendsTheDocumentedRequestShape() throws Exception {
        service("BusGo <sender@example.com>").send(
                new OutgoingEmail("asha@example.com", "Your BusGo password reset code", "Hi Asha,\n\nYour code is 123456 <b>&"));

        Captured c = requests.poll(5, TimeUnit.SECONDS);
        assertNotNull(c, "the email must be POSTed to Brevo");
        assertEquals("POST", c.method());
        assertEquals("test-api-key-123", c.apiKey(), "the key goes in the api-key header, never in the body or URL");
        assertTrue(c.contentType().contains("application/json"));
        assertFalse(c.body().contains("test-api-key-123"));

        JsonNode json = new ObjectMapper().readTree(c.body());
        assertEquals("BusGo", json.get("sender").get("name").asText());
        assertEquals("sender@example.com", json.get("sender").get("email").asText());
        assertEquals("asha@example.com", json.get("to").get(0).get("email").asText());
        assertEquals("Your BusGo password reset code", json.get("subject").asText());
        assertTrue(json.get("textContent").asText().contains("123456"));
        String html = json.get("htmlContent").asText();
        assertTrue(html.contains("123456"), "an HTML body is sent too (Brevo requires htmlContent without a template)");
        assertTrue(html.contains("&lt;b&gt;") && html.contains("&amp;"), "text must be HTML-escaped in the HTML body");
        assertFalse(html.contains("<b>"));
    }

    @Test
    void aPlainAddressWorksAsTheSenderToo() throws Exception {
        service("only@example.com").send(new OutgoingEmail("a@example.com", "Subject", "Body"));
        JsonNode json = new ObjectMapper().readTree(requests.poll(5, TimeUnit.SECONDS).body());
        assertEquals("only@example.com", json.get("sender").get("email").asText());
        assertEquals("BusGo", json.get("sender").get("name").asText());
    }

    @Test
    void lineBreaksInTheSubjectCannotInjectHeaders() throws Exception {
        service("BusGo <sender@example.com>").send(new OutgoingEmail("a@example.com", "Hello\r\nBcc: evil@example.com", "Body"));
        JsonNode json = new ObjectMapper().readTree(requests.poll(5, TimeUnit.SECONDS).body());
        assertFalse(json.get("subject").asText().contains("\n"));
    }

    @Test
    void aRefusalFromBrevoNeverBreaksTheCaller() throws Exception {
        responseStatus = 401; // e.g. wrong API key or unverified sender
        BrevoMailService service = service("BusGo <sender@example.com>");
        assertDoesNotThrow(() -> service.send(new OutgoingEmail("a@example.com", "Subject", "Body")));
        assertNotNull(requests.poll(5, TimeUnit.SECONDS), "the request was still attempted");
    }

    @Test
    void anUnreachableApiNeverBreaksTheCaller() throws Exception {
        BrevoMailService service = new BrevoMailService(new ObjectMapper(), "k", "http://127.0.0.1:1/none", "BusGo <s@example.com>");
        assertDoesNotThrow(() -> service.send(new OutgoingEmail("a@example.com", "Subject", "Body")));
        Thread.sleep(800);
    }

    @Test
    void missingConfigurationFailsAtStartupWithAClearMessage() {
        IllegalStateException noKey = assertThrows(IllegalStateException.class,
                () -> new BrevoMailService(new ObjectMapper(), "", url, "BusGo <s@example.com>"));
        assertTrue(noKey.getMessage().contains("BREVO_API_KEY"));
        IllegalStateException noFrom = assertThrows(IllegalStateException.class,
                () -> new BrevoMailService(new ObjectMapper(), "key", url, ""));
        assertTrue(noFrom.getMessage().contains("MAIL_FROM"));
        assertTrue(service("BusGo <s@example.com>").isDeliveryEnabled());
    }
}
