package com.example.busbooking.repository;

import com.example.busbooking.entity.SavedPassenger;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface SavedPassengerRepository extends JpaRepository<SavedPassenger, Long> {

    List<SavedPassenger> findByUserIdOrderByCreatedAtDesc(Long userId);

    long countByUserId(Long userId);

    boolean existsByUserIdAndNameIgnoreCaseAndAgeAndGender(Long userId, String name, int age, String gender);
}
