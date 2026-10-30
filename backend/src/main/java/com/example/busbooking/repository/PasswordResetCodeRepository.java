package com.example.busbooking.repository;

import com.example.busbooking.entity.PasswordResetCode;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface PasswordResetCodeRepository extends JpaRepository<PasswordResetCode, Long> {

    Optional<PasswordResetCode> findFirstByUserIdOrderByCreatedAtDescIdDesc(Long userId);

    List<PasswordResetCode> findByUserId(Long userId);
}
