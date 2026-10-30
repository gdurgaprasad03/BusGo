package com.example.busbooking;

import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import java.util.Map;

import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.not;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class HealthAndAuthTest extends IntegrationTestBase {

    private String registerJson(String email) throws Exception {
        return json.writeValueAsString(Map.of(
                "fullName", "Asha Rao", "email", email, "phone", "9876543210", "password", "Password123"));
    }

    @Test
    void healthEndpointIsPublic() throws Exception {
        mvc.perform(get("/api/health")).andExpect(status().isOk()).andExpect(jsonPath("$.status").value("UP"));
    }

    @Test
    void registerReturnsTokenAndNeverExposesPassword() throws Exception {
        mvc.perform(post("/api/auth/register").contentType(MediaType.APPLICATION_JSON).content(registerJson("asha@example.com")))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.token").isNotEmpty())
                .andExpect(jsonPath("$.user.email").value("asha@example.com"))
                .andExpect(content().string(not(containsString("password"))));
    }

    @Test
    void passwordIsStoredAsBcryptHash() throws Exception {
        mvc.perform(post("/api/auth/register").contentType(MediaType.APPLICATION_JSON).content(registerJson("hash@example.com")));
        String stored = jdbc.queryForObject("SELECT password_hash FROM users WHERE email='hash@example.com'", String.class);
        org.junit.jupiter.api.Assertions.assertTrue(stored.startsWith("$2"), "expected a BCrypt hash");
    }

    @Test
    void duplicateEmailIsRejectedWith409() throws Exception {
        mvc.perform(post("/api/auth/register").contentType(MediaType.APPLICATION_JSON).content(registerJson("dup@example.com")));
        mvc.perform(post("/api/auth/register").contentType(MediaType.APPLICATION_JSON).content(registerJson("DUP@example.com")))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.message").value("An account with this email already exists"));
    }

    @Test
    void invalidRegistrationReturns400WithFieldErrors() throws Exception {
        String bad = json.writeValueAsString(Map.of("fullName", "", "email", "not-an-email", "phone", "123", "password", "short"));
        mvc.perform(post("/api/auth/register").contentType(MediaType.APPLICATION_JSON).content(bad))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.fieldErrors.email").exists())
                .andExpect(jsonPath("$.fieldErrors.phone").exists())
                .andExpect(jsonPath("$.fieldErrors.password").exists())
                .andExpect(jsonPath("$.fieldErrors.fullName").exists());
    }

    @Test
    void loginSucceedsWithCorrectPasswordAndFailsWithWrongOne() throws Exception {
        mvc.perform(post("/api/auth/register").contentType(MediaType.APPLICATION_JSON).content(registerJson("login@example.com")));
        mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("email", "login@example.com", "password", "Password123"))))
                .andExpect(status().isOk()).andExpect(jsonPath("$.token").isNotEmpty());
        mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("email", "login@example.com", "password", "WrongPassword"))))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.message").value("Invalid email/mobile number or password"));
    }

    @Test
    void loginAlsoWorksWithMobileNumber() throws Exception {
        mvc.perform(post("/api/auth/register").contentType(MediaType.APPLICATION_JSON).content(registerJson("mobile@example.com")));
        mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("identifier", "9876543210", "password", "Password123"))))
                .andExpect(status().isOk()).andExpect(jsonPath("$.user.email").value("mobile@example.com"));
        mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("identifier", "9876543210", "password", "WrongPassword"))))
                .andExpect(status().isUnauthorized());
        mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("identifier", "9000000000", "password", "Password123"))))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void profileRequiresTokenAndCanBeUpdated() throws Exception {
        mvc.perform(get("/api/users/me")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/users/me").header("Authorization", "Bearer garbage.token.value")).andExpect(status().isUnauthorized());

        String token = registerUser();
        mvc.perform(get("/api/users/me").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk()).andExpect(jsonPath("$.fullName").value("Test User"));
        mvc.perform(put("/api/users/me").header("Authorization", "Bearer " + token).contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("fullName", "New Name", "phone", "9123456789"))))
                .andExpect(status().isOk()).andExpect(jsonPath("$.fullName").value("New Name"));
        mvc.perform(put("/api/users/me").header("Authorization", "Bearer " + token).contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("fullName", "New Name", "phone", "abc"))))
                .andExpect(status().isBadRequest());
    }
}
