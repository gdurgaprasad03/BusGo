package com.example.busbooking;

import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Saved passengers, complaints and the demo password reset. */
class ProfileFeaturesTest extends IntegrationTestBase {

    private String bearer(String token) {
        return "Bearer " + token;
    }

    private String passengerJson(String name, int age, String gender) throws Exception {
        return json.writeValueAsString(Map.of("name", name, "age", age, "gender", gender));
    }

    @Test
    void savedPassengersCanBeAddedListedAndDeleted() throws Exception {
        String token = registerUser();
        mvc.perform(post("/api/users/me/passengers").header("Authorization", bearer(token))
                        .contentType(MediaType.APPLICATION_JSON).content(passengerJson("Ravi Kumar", 25, "MALE")))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.name").value("Ravi Kumar"));
        long id = body(mvc.perform(post("/api/users/me/passengers").header("Authorization", bearer(token))
                .contentType(MediaType.APPLICATION_JSON).content(passengerJson("Sriya", 23, "FEMALE")))).get("id").asLong();

        assertEquals(2, body(mvc.perform(get("/api/users/me/passengers").header("Authorization", bearer(token)))).size());

        mvc.perform(delete("/api/users/me/passengers/" + id).header("Authorization", bearer(token)))
                .andExpect(status().isNoContent());
        assertEquals(1, body(mvc.perform(get("/api/users/me/passengers").header("Authorization", bearer(token)))).size());
    }

    @Test
    void savedPassengerValidationDuplicatesAndOwnership() throws Exception {
        String alice = registerUser();
        String bob = registerUser();
        mvc.perform(post("/api/users/me/passengers").header("Authorization", bearer(alice))
                        .contentType(MediaType.APPLICATION_JSON).content(passengerJson("", 0, "ROBOT")))
                .andExpect(status().isBadRequest());

        long id = body(mvc.perform(post("/api/users/me/passengers").header("Authorization", bearer(alice))
                .contentType(MediaType.APPLICATION_JSON).content(passengerJson("Asha", 30, "FEMALE")))).get("id").asLong();
        mvc.perform(post("/api/users/me/passengers").header("Authorization", bearer(alice))
                        .contentType(MediaType.APPLICATION_JSON).content(passengerJson("asha", 30, "FEMALE")))
                .andExpect(status().isConflict());

        // Bob cannot see or delete Alice's passenger.
        assertEquals(0, body(mvc.perform(get("/api/users/me/passengers").header("Authorization", bearer(bob)))).size());
        mvc.perform(delete("/api/users/me/passengers/" + id).header("Authorization", bearer(bob))).andExpect(status().isForbidden());
        mvc.perform(get("/api/users/me/passengers")).andExpect(status().isUnauthorized());
    }

    @Test
    void passengerLimitIsEnforced() throws Exception {
        String token = registerUser();
        for (int i = 0; i < 10; i++) {
            mvc.perform(post("/api/users/me/passengers").header("Authorization", bearer(token))
                    .contentType(MediaType.APPLICATION_JSON).content(passengerJson("Person " + i, 20 + i, "OTHER")))
                    .andExpect(status().isCreated());
        }
        mvc.perform(post("/api/users/me/passengers").header("Authorization", bearer(token))
                        .contentType(MediaType.APPLICATION_JSON).content(passengerJson("One too many", 40, "OTHER")))
                .andExpect(status().isBadRequest());
    }

    @Test
    void complaintsCanBeRaisedAndListedAndOnlyForOwnBookings() throws Exception {
        String alice = registerUser();
        String bob = registerUser();
        long tripId = firstKurnoolTrip().get("tripId").asLong();
        String reference = body(book(alice, tripId, freeSeats(tripId).subList(0, 1))).get("bookingReference").asText();

        JsonNode created = body(mvc.perform(post("/api/complaints").header("Authorization", bearer(alice))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("bookingReference", reference,
                                "subject", "Bus was late", "message", "The bus arrived one hour late."))))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.status").value("OPEN")));
        assertEquals(true, created.get("reference").asText().startsWith("CMP"));
        assertEquals(1, body(mvc.perform(get("/api/complaints/my").header("Authorization", bearer(alice)))).size());

        // Bob cannot attach Alice's booking, but can raise a general complaint.
        mvc.perform(post("/api/complaints").header("Authorization", bearer(bob)).contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("bookingReference", reference,
                                "subject", "Not mine", "message", "This booking belongs to someone else."))))
                .andExpect(status().isBadRequest());
        mvc.perform(post("/api/complaints").header("Authorization", bearer(bob)).contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("subject", "General", "message", "App feedback goes here."))))
                .andExpect(status().isCreated());
        assertEquals(0, body(mvc.perform(get("/api/complaints/my").header("Authorization", bearer(alice)))).size() - 1);

        mvc.perform(post("/api/complaints").header("Authorization", bearer(alice)).contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("subject", "", "message", "short"))))
                .andExpect(status().isBadRequest());
        mvc.perform(get("/api/complaints/my")).andExpect(status().isUnauthorized());
    }
}
