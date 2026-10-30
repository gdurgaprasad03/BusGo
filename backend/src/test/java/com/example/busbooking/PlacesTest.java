package com.example.busbooking;

import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** City autocomplete, the state list and name normalisation in trip search. */
class PlacesTest extends IntegrationTestBase {

    private JsonNode places(String query) throws Exception {
        return body(mvc.perform(get("/api/places").param("query", query).param("limit", "50")));
    }

    private boolean contains(JsonNode list, String name) {
        for (JsonNode p : list) {
            if (p.get("name").asText().equals(name)) return true;
        }
        return false;
    }

    @Test
    void autocompleteIsCaseInsensitiveAndMatchesPrefixes() throws Exception {
        assertTrue(contains(places("kur"), "Kurnool"));
        assertTrue(contains(places("HYDER"), "Hyderabad"));
        assertTrue(contains(places("  warangal "), "Warangal"));
        assertEquals(0, places("zzzzqqqq").size());
    }

    @Test
    void oldAndAlternativeNamesFindTheModernCity() throws Exception {
        assertEquals("Bengaluru", places("bangalore").get(0).get("name").asText());
        assertEquals("Mumbai", places("bombay").get(0).get("name").asText());
        assertEquals("Visakhapatnam", places("vizag").get(0).get("name").asText());
        assertEquals("Panaji", places("goa").get(0).get("name").asText());
    }

    @Test
    void everyResultCarriesItsStateAndWhetherDemoBusesRunThere() throws Exception {
        JsonNode kurnool = places("kurnool").get(0);
        assertEquals("Andhra Pradesh", kurnool.get("state").asText());
        assertTrue(kurnool.get("hasService").asBoolean(), "Kurnool has demo routes");

        // A real city that is in the catalog but has no demo route in the test data.
        JsonNode surat = places("surat").get(0);
        assertEquals("Gujarat", surat.get("state").asText());
        assertFalse(surat.get("hasService").asBoolean(), "being listed does not mean buses run there");
    }

    @Test
    void stateFilterRestrictsResultsAndUnknownStatesAreRejected() throws Exception {
        JsonNode telangana = body(mvc.perform(get("/api/places").param("state", "Telangana").param("limit", "100")));
        assertTrue(telangana.size() > 20);
        for (JsonNode p : telangana) {
            assertEquals("Telangana", p.get("state").asText());
        }
        assertTrue(contains(telangana, "Hyderabad"));

        mvc.perform(get("/api/places").param("state", "Atlantis")).andExpect(status().isBadRequest());
    }

    @Test
    void emptyQueryListsTheBiggestCitiesAndLimitIsRespected() throws Exception {
        JsonNode top = body(mvc.perform(get("/api/places").param("limit", "5")));
        assertEquals(5, top.size());
        assertEquals("Mumbai", top.get(0).get("name").asText()); // the biggest city in the catalog data
    }

    @Test
    void catalogCoversEveryStateAndUnionTerritory() throws Exception {
        mvc.perform(get("/api/places/states"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(36));
        JsonNode states = body(mvc.perform(get("/api/places/states")));
        int unionTerritories = 0;
        for (JsonNode s : states) {
            assertTrue(s.get("placeCount").asInt() > 0, s.get("name").asText() + " must have places");
            if (s.get("type").asText().equals("UNION_TERRITORY")) unionTerritories++;
        }
        assertEquals(8, unionTerritories);
        assertTrue(states.toString().contains("Lakshadweep"));
        assertTrue(states.toString().contains("Telangana"));
    }

    @Test
    void tripSearchUnderstandsAlternativeNames() throws Exception {
        // "bangalore" is turned into "Bengaluru" before searching.
        JsonNode trips = body(mvc.perform(get("/api/trips/search?source=hyderabad&destination=BANGALORE&date=" + tomorrow)));
        assertTrue(trips.size() >= 3);
        assertEquals("Bengaluru", trips.get(0).get("destination").asText());
    }

    @Test
    void everySearchResultIsLabelledAsDemoData() throws Exception {
        for (JsonNode t : search("Kurnool", "Hyderabad", "")) {
            assertEquals("demo", t.get("provider").asText());
            assertEquals("DEMO", t.get("dataSource").asText());
            assertTrue(t.get("bookable").asBoolean());
        }
    }
}
