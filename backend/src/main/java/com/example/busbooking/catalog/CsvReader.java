package com.example.busbooking.catalog;

import org.springframework.core.io.ClassPathResource;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

/** Minimal CSV reader for the small data files in src/main/resources/data (handles quoted fields). */
final class CsvReader {

    private CsvReader() {
    }

    /** Reads a classpath CSV and returns every data row (the header row is skipped). */
    static List<String[]> read(String classpathLocation) {
        List<String[]> rows = new ArrayList<>();
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(
                new ClassPathResource(classpathLocation).getInputStream(), StandardCharsets.UTF_8))) {
            String line = reader.readLine(); // header
            while ((line = reader.readLine()) != null) {
                if (!line.isBlank()) {
                    rows.add(split(line));
                }
            }
        } catch (IOException e) {
            throw new UncheckedIOException("Could not read " + classpathLocation, e);
        }
        return rows;
    }

    static String[] split(String line) {
        List<String> fields = new ArrayList<>();
        StringBuilder current = new StringBuilder();
        boolean quoted = false;
        for (int i = 0; i < line.length(); i++) {
            char c = line.charAt(i);
            if (quoted) {
                if (c == '"' && i + 1 < line.length() && line.charAt(i + 1) == '"') {
                    current.append('"');
                    i++;
                } else if (c == '"') {
                    quoted = false;
                } else {
                    current.append(c);
                }
            } else if (c == '"') {
                quoted = true;
            } else if (c == ',') {
                fields.add(current.toString());
                current.setLength(0);
            } else {
                current.append(c);
            }
        }
        fields.add(current.toString());
        return fields.toArray(new String[0]);
    }
}
