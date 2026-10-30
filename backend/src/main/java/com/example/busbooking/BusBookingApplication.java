package com.example.busbooking;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Entry point. @SpringBootApplication = @Configuration + @EnableAutoConfiguration + @ComponentScan,
 * so Spring scans this package (and sub-packages) for controllers, services and repositories.
 */
@SpringBootApplication
public class BusBookingApplication {

    public static void main(String[] args) {
        SpringApplication.run(BusBookingApplication.class, args);
    }
}
