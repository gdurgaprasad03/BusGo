package com.example.busbooking.mail;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import jakarta.annotation.PreDestroy;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnExpression;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Sends email through Brevo's HTTPS API (https://developers.brevo.com) instead of SMTP. Many cloud hosts, including
 * Render's free plan, block outgoing SMTP ports, but HTTPS always works. Enable with
 * {@code app.mail.enabled=true} and {@code app.mail.provider=brevo}; see docs/DEPLOY_RENDER.md.
 *
 * The sender address in {@code app.mail.from} must be a sender you verified in your Brevo account.
 * Like the SMTP sender, it works on a background thread and only logs failures (never the API key or message body).
 */
@Service
@ConditionalOnExpression("'${app.mail.enabled:false}' == 'true' and '${app.mail.provider:smtp}' == 'brevo'")
public class BrevoMailService implements MailService {

    private static final Logger log = LoggerFactory.getLogger(BrevoMailService.class);
    private static final Pattern NAME_AND_ADDRESS = Pattern.compile("^\\s*(?:\"?([^\"<]*?)\"?\\s*)?<([^>]+)>\\s*$");

    private final ObjectMapper objectMapper;
    private final String apiKey;
    private final String url;
    private final String senderName;
    private final String senderEmail;
    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build();
    private final ExecutorService executor = Executors.newSingleThreadExecutor(r -> {
        Thread t = new Thread(r, "brevo-mail-sender");
        t.setDaemon(true);
        return t;
    });

    public BrevoMailService(ObjectMapper objectMapper,
                            @Value("${app.mail.brevo.api-key:}") String apiKey,
                            @Value("${app.mail.brevo.url:https://api.brevo.com/v3/smtp/email}") String url,
                            @Value("${app.mail.from:}") String from) {
        this.objectMapper = objectMapper;
        this.apiKey = apiKey;
        this.url = url;
        if (apiKey.isBlank()) {
            throw new IllegalStateException("app.mail.provider=brevo needs BREVO_API_KEY. See docs/DEPLOY_RENDER.md.");
        }
        if (from.isBlank()) {
            throw new IllegalStateException("app.mail.provider=brevo needs MAIL_FROM (a sender verified in Brevo).");
        }
        Matcher m = NAME_AND_ADDRESS.matcher(from);
        if (m.matches()) {
            this.senderName = m.group(1) == null || m.group(1).isBlank() ? "BusGo" : m.group(1).trim();
            this.senderEmail = m.group(2).trim();
        } else {
            this.senderName = "BusGo";
            this.senderEmail = from.trim();
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
            HttpRequest request = HttpRequest.newBuilder(URI.create(url))
                    .timeout(Duration.ofSeconds(10))
                    .header("api-key", apiKey)
                    .header("accept", "application/json")
                    .header("content-type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(buildBody(email)))
                    .build();
            HttpResponse<String> response = http.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() / 100 == 2) {
                log.info("Email sent to {} (Brevo, HTTP {})", SmtpMailService.mask(email.to()), response.statusCode());
            } else {
                // Only the status code: the response can echo the request.
                log.warn("Brevo refused the email to {}: HTTP {}. Check BREVO_API_KEY and that MAIL_FROM is a verified sender.",
                        SmtpMailService.mask(email.to()), response.statusCode());
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        } catch (Exception e) {
            log.warn("Could not send email to {}: {}", SmtpMailService.mask(email.to()), e.getClass().getSimpleName());
        }
    }

    /** Both an HTML and a plain-text body are sent: Brevo documents htmlContent as required when no template is used. */
    String buildBody(OutgoingEmail email) throws Exception {
        ObjectNode root = objectMapper.createObjectNode();
        root.putObject("sender").put("name", senderName).put("email", senderEmail);
        ArrayNode to = root.putArray("to");
        to.addObject().put("email", email.to());
        root.put("subject", email.subject().replaceAll("[\\r\\n]+", " "));
        root.put("textContent", email.body());
        root.put("htmlContent", "<div style=\"font-family:Arial,sans-serif;font-size:14px;white-space:pre-wrap\">"
                + escapeHtml(email.body()) + "</div>");
        return objectMapper.writeValueAsString(root);
    }

    private static String escapeHtml(String text) {
        return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;");
    }

    @PreDestroy
    void stop() {
        executor.shutdown();
    }
}
