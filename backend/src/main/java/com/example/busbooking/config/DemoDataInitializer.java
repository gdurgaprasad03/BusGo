package com.example.busbooking.config;

import com.example.busbooking.service.DemoDataService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * On startup, tops up demo trips so searches for upcoming dates always return results.
 * It runs on a background thread: the very first start creates about 10,000 trips, which can take minutes when the
 * database is a remote one, and the app (and the host's health check) must not wait for that. Searches simply return
 * fewer buses until it has finished; the log says when it is done.
 */
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
        Thread worker = new Thread(() -> {
            try {
                long started = System.currentTimeMillis();
                int created = demoDataService.seedUpcomingTrips();
                log.info("Demo data check complete: {} new trip(s) created in {} s", created,
                        (System.currentTimeMillis() - started) / 1000);
            } catch (Exception e) {
                log.error("Demo data seeding failed: {}", e.getClass().getSimpleName(), e);
            }
        }, "demo-data-seeder");
        worker.setDaemon(true);
        worker.start();
    }
}
