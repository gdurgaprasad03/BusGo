package com.example.busbooking.repository;

import com.example.busbooking.entity.Complaint;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface ComplaintRepository extends JpaRepository<Complaint, Long> {

    List<Complaint> findByUserIdOrderByCreatedAtDesc(Long userId);
}
