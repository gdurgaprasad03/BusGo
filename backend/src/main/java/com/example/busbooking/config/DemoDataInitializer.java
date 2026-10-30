package com.example.busbooking.config;

import com.example.busbooking.service.DemoDataService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/** On startup, tops up demo trips so searches for upcoming dates always return results. */
@Component
@ConditionalOnProperty(name = "app.demo.seed-on-startup", havingValue = "true")
public class DemoDataInitializer implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(DemoDataInitializer.class);
    private final DemoDataService demoDataService;

    public DemoDataInitializer(DemoDataService demoDataService) {
        this.demoDataService = demoDataService;
    }

    @Override
    public void run(ApplicationArguments args) {
        int created = demoDataService.seedUpcomingTrips();
        log.info("Demo data check complete: {} new trip(s) created", created);
    }
}
