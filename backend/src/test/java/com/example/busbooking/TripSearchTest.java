package com.example.busbooking;

import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class TripSearchTest extends IntegrationTestBase {

    @Test
    void searchReturnsTripsWithRequiredFieldsWithoutLogin() throws Exception {
        JsonNode trips = search("Kurnool", "Hyderabad", "");
        assertTrue(trips.size() >= 3, "expected several Kurnool -> Hyderabad trips");
        JsonNode t = trips.get(0);
        for (String field : new String[]{"tripId", "operatorName", "operatorRating", "busType", "source", "destination",
                "departureTime", "arrivalTime", "durationMinutes", "fare", "availableSeats"}) {
            assertTrue(t.has(field), "missing field " + field);
        }
        assertEquals("Kurnool", t.get("source").asText());
        assertEquals(270, t.get("durationMinutes").asInt());
    }

    @Test
    void searchIsCaseInsensitiveAndSortedByDeparture() throws Exception {
        JsonNode trips = search("kurnool", "HYDERABAD", "");
        String previous = "";
        for (JsonNode t : trips) {
            String dep = t.get("departureTime").asText();
            assertTrue(dep.compareTo(previous) >= 0, "results should be sorted by departure time");
            previous = dep;
        }
    }

    @Test
    void fullyBookedTripsAreExcludedFromSearchResults() throws Exception {
        // The 23:45 Sunrise Travels bus on this route is seeded 100% sold out.
        JsonNode trips = search("Kurnool", "Hyderabad", "");
        for (JsonNode t : trips) {
            assertTrue(t.get("availableSeats").asInt() > 0);
            assertTrue(!t.get("departureTime").asText().contains("T23:45"), "sold-out trip must not be listed");
        }
        assertEquals(4, trips.size(), "5 trips are scheduled, 1 is sold out");
        // Hyderabad -> Vijayawada also has a sold-out 23:30 sleeper.
        for (JsonNode t : search("Hyderabad", "Vijayawada", "")) {
            assertTrue(!t.get("departureTime").asText().contains("T23:30"));
        }
    }

    @Test
    void availabilityComesFromDatabaseAndIncludesFewSeatsLeftTrips() throws Exception {
        JsonNode trips = search("Kurnool", "Hyderabad", "");
        boolean sawMany = false;
        boolean sawFew = false;
        for (JsonNode t : trips) {
            int available = t.get("availableSeats").asInt();
            sawMany |= available >= 20;
            sawFew |= available <= 3;
        }
        assertTrue(sawMany, "expected a trip with many seats");
        assertTrue(sawFew, "expected a trip with only a few seats left");
    }

    @Test
    void departureTimeAndBusTypeFiltersWork() throws Exception {
        JsonNode evening = search("Kurnool", "Hyderabad", "&departureFrom=18:00&departureTo=23:59");
        assertEquals(2, evening.size()); // 21:30 sleeper and 23:00 sleeper (23:45 is sold out)
        for (JsonNode t : evening) {
            assertTrue(t.get("busType").asText().endsWith("SLEEPER"));
        }
        JsonNode acSleeper = search("Kurnool", "Hyderabad", "&busType=AC_SLEEPER");
        assertEquals(1, acSleeper.size());
        assertEquals("AC_SLEEPER", acSleeper.get(0).get("busType").asText());
    }

    @Test
    void searchValidatesInput() throws Exception {
        mvc.perform(get("/api/trips/search?source=Kurnool&destination=Kurnool&date=" + tomorrow))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.message").value("Source and destination must be different"));
        mvc.perform(get("/api/trips/search?source=Kurnool&date=" + tomorrow))
                .andExpect(status().isBadRequest());
        mvc.perform(get("/api/trips/search?source=Kurnool&destination=Hyderabad&date=25-10-2026"))
                .andExpect(status().isBadRequest());
        mvc.perform(get("/api/trips/search?source=Kurnool&destination=Hyderabad&date=" + tomorrow + "&busType=SPACESHIP"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void unknownRouteOrPastDateReturnsEmptyList() throws Exception {
        mvc.perform(get("/api/trips/search?source=Kurnool&destination=Delhi&date=" + tomorrow))
                .andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(0));
        mvc.perform(get("/api/trips/search?source=Kurnool&destination=Hyderabad&date=2020-01-01"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(0));
    }

    @Test
    void seatLayoutDescribesSeaterAndSleeperBuses() throws Exception {
        JsonNode seater = search("Kurnool", "Hyderabad", "&busType=AC_SEATER").get(0);
        mvc.perform(get("/api/trips/" + seater.get("tripId").asLong() + "/seats"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.decks").value(1))
                .andExpect(jsonPath("$.columns").value(4))
                .andExpect(jsonPath("$.aisleAfterColumn").value(2))
                .andExpect(jsonPath("$.seats.length()").value(40));

        JsonNode sleeper = search("Kurnool", "Hyderabad", "&busType=AC_SLEEPER").get(0);
        mvc.perform(get("/api/trips/" + sleeper.get("tripId").asLong() + "/seats"))
                .andExpect(jsonPath("$.decks").value(2))
                .andExpect(jsonPath("$.columns").value(3))
                .andExpect(jsonPath("$.seats.length()").value(30));
    }

    @Test
    void additionalCitiesAndRoutesHaveDemoTripsInBothDirections() throws Exception {
        String[][] routes = {{"Delhi", "Agra"}, {"Agra", "Delhi"}, {"Mumbai", "Goa"}, {"Goa", "Mumbai"},
                {"Bengaluru", "Mysuru"}, {"Hyderabad", "Visakhapatnam"}, {"Chennai", "Madurai"}, {"Kurnool", "Bengaluru"},
                {"Warangal", "Kurnool"}, {"Kurnool", "Warangal"}, {"Warangal", "Hyderabad"}, {"Guntur", "Vijayawada"}};
        for (String[] route : routes) {
            JsonNode trips = search(route[0], route[1], "");
            assertTrue(trips.size() >= 3, route[0] + " -> " + route[1] + " should have trips, got " + trips.size());
        }
        // Long routes (8h+) include a nearly full overnight sleeper.
        boolean sawFew = false;
        for (JsonNode t : search("Mumbai", "Goa", "")) {
            sawFew |= t.get("availableSeats").asInt() <= 3;
        }
        assertTrue(sawFew, "Mumbai -> Goa should include a trip with only a few seats left");
    }

    @Test
    void unknownTripReturns404() throws Exception {
        mvc.perform(get("/api/trips/999999")).andExpect(status().isNotFound());
        mvc.perform(get("/api/trips/999999/seats")).andExpect(status().isNotFound());
        mvc.perform(get("/api/trips/abc")).andExpect(status().isBadRequest());
    }
}
