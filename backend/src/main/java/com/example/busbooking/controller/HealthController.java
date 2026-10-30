package com.example.busbooking.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDateTime;
import java.util.Map;

/** Simple "is the server up?" check, used by the Flutter app's retry logic and for manual testing. */
@RestController
@RequestMapping("/api/health")
public class HealthController {

    @GetMapping
    public Map<String, Object> health() {
        return Map.of("status", "UP", "app", "BusGo API", "time", LocalDateTime.now().toString());
    }
}
