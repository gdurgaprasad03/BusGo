package com.example.busbooking.controller;

import com.example.busbooking.service.DemoDataService;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * Development helper. Only exists when app.demo.reset-enabled=true, so it is absent by default
 * (the URL simply returns 401/404). WARNING: wipes all bookings.
 */
@RestController
@RequestMapping("/api/demo")
@ConditionalOnProperty(name = "app.demo.reset-enabled", havingValue = "true")
public class DemoController {

    private final DemoDataService demoDataService;

    public DemoController(DemoDataService demoDataService) {
        this.demoDataService = demoDataService;
    }

    @PostMapping("/reset")
    public Map<String, String> reset() {
        demoDataService.reset();
        return Map.of("message", "Demo data reset. Bookings were deleted and trips regenerated.");
    }
}
