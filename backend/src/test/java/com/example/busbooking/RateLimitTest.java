package com.example.busbooking;

import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;

import java.util.Map;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@TestPropertySource(properties = "app.rate-limit.auth-per-minute=3")
class RateLimitTest extends IntegrationTestBase {

    @Test
    void repeatedLoginAttemptsAreThrottledWith429() throws Exception {
        String bad = json.writeValueAsString(Map.of("identifier", "nobody@example.com", "password", "wrongpass1"));
        for (int i = 0; i < 3; i++) {
            mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON).content(bad))
                    .andExpect(status().isUnauthorized());
        }
        mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON).content(bad))
                .andExpect(status().isTooManyRequests())
                .andExpect(header().exists("Retry-After"));
    }

    @Test
    void otherEndpointsAreNotThrottled() throws Exception {
        for (int i = 0; i < 6; i++) {
            mvc.perform(get("/api/health")).andExpect(status().isOk());
        }
    }
}
