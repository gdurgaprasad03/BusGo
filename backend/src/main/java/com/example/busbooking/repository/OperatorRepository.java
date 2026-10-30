package com.example.busbooking.repository;

import com.example.busbooking.entity.Operator;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface OperatorRepository extends JpaRepository<Operator, Long> {

    Optional<Operator> findByName(String name);
}
