package com.example.busbooking.repository;

import com.example.busbooking.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

/** Spring Data generates the implementation from the method names. */
public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByEmailIgnoreCase(String email);

    boolean existsByEmailIgnoreCase(String email);

    Optional<User> findByGoogleSub(String googleSub);

    /** Phone numbers are not unique, so several users could share one. */
    java.util.List<User> findByPhone(String phone);
}
