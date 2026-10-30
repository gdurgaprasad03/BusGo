package com.example.busbooking.repository;

import com.example.busbooking.entity.Bus;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface BusRepository extends JpaRepository<Bus, Long> {

    Optional<Bus> findByRegistrationNumber(String registrationNumber);
}
