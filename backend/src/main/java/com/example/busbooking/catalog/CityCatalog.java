package com.example.busbooking.catalog;

import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;

/**
 * The searchable list of places in India (about 6,200 cities and towns across all 28 states and 8 union
 * territories), loaded once at startup from src/main/resources/data. Source: GeoNames, CC BY 4.0.
 * See tools/build_demo_data.py for how the files are produced and updated.
 *
 * IMPORTANT: a place being in this catalog does NOT mean buses run there. Only the routes in
 * demo-routes.csv have (fictional) demo trips.
 */
@Component
public class CityCatalog {

    public record City(String name, String state, double lat, double lon, long population) {}

    public record StateInfo(String name, String type) {}

    private final List<City> cities = new ArrayList<>();
    private final Map<String, City> byLowerName = new HashMap<>();
    private final Map<String, String> aliasToCity = new HashMap<>();
    private final List<StateInfo> states = new ArrayList<>();

    public CityCatalog() {
        for (String[] r : CsvReader.read("data/india-cities.csv")) {
            City city = new City(r[0], r[1], Double.parseDouble(r[2]), Double.parseDouble(r[3]), Long.parseLong(r[4]));
            cities.add(city);
            byLowerName.put(city.name().toLowerCase(Locale.ROOT), city);
        }
        for (String[] r : CsvReader.read("data/india-city-aliases.csv")) {
            aliasToCity.put(r[0].toLowerCase(Locale.ROOT), r[1]);
        }
        for (String[] r : CsvReader.read("data/india-states.csv")) {
            states.add(new StateInfo(r[0], r[1]));
        }
    }

    public int size() {
        return cities.size();
    }

    public List<StateInfo> states() {
        return List.copyOf(states);
    }

    public List<City> citiesInState(String state) {
        return cities.stream().filter(c -> c.state().equalsIgnoreCase(state)).toList();
    }

    public Optional<City> find(String name) {
        if (name == null) {
            return Optional.empty();
        }
        String key = name.trim().toLowerCase(Locale.ROOT);
        City direct = byLowerName.get(key);
        if (direct != null) {
            return Optional.of(direct);
        }
        String aliased = aliasToCity.get(key);
        return aliased == null ? Optional.empty() : Optional.ofNullable(byLowerName.get(aliased.toLowerCase(Locale.ROOT)));
    }

    /**
     * Turns what the user typed into the catalog's name: "bangalore" and "BENGALURU" both become "Bengaluru".
     * A place that is not in the catalog is returned trimmed, so the search simply finds no buses for it.
     */
    public String canonicalName(String input) {
        if (input == null) {
            return "";
        }
        return find(input).map(City::name).orElse(input.trim());
    }

    /**
     * Autocomplete. Ranking: exact name or alias, then names starting with the text, then words starting
     * with it, then names containing it. Ties go to the bigger city. An empty query lists the biggest cities.
     */
    public List<City> search(String query, String state, int limit) {
        String q = query == null ? "" : query.trim().toLowerCase(Locale.ROOT);
        int max = Math.max(1, Math.min(limit, 100));
        record Scored(City city, int score) {}

        List<Scored> hits = new ArrayList<>();
        for (City city : cities) {
            if (state != null && !state.isBlank() && !city.state().equalsIgnoreCase(state.trim())) {
                continue;
            }
            int score = q.isEmpty() ? 0 : score(city.name().toLowerCase(Locale.ROOT), q);
            if (score < 0) {
                continue;
            }
            hits.add(new Scored(city, score));
        }
        // An alias such as "bangalore" or "vizag" brings its city to the top.
        if (!q.isEmpty()) {
            for (Map.Entry<String, String> e : aliasToCity.entrySet()) {
                if (e.getKey().startsWith(q)) {
                    City target = byLowerName.get(e.getValue().toLowerCase(Locale.ROOT));
                    boolean stateOk = state == null || state.isBlank() || (target != null && target.state().equalsIgnoreCase(state.trim()));
                    if (target != null && stateOk) {
                        hits.removeIf(h -> h.city().equals(target));
                        hits.add(new Scored(target, e.getKey().equals(q) ? 0 : 1));
                    }
                }
            }
        }
        return hits.stream()
                .sorted(Comparator.comparingInt(Scored::score)
                        .thenComparing((Scored s) -> -s.city().population())
                        .thenComparing(s -> s.city().name()))
                .limit(max)
                .map(Scored::city)
                .toList();
    }

    /** Lower is better; -1 means no match. */
    private static int score(String name, String q) {
        if (name.equals(q)) {
            return 0;
        }
        if (name.startsWith(q)) {
            return 1;
        }
        if (name.contains(" " + q)) {
            return 2;
        }
        return name.contains(q) ? 3 : -1;
    }
}
