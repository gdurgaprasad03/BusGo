package com.example.busbooking.controller;

import com.example.busbooking.dto.ComplaintRequest;
import com.example.busbooking.dto.ComplaintResponse;
import com.example.busbooking.service.ComplaintService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/complaints")
public class ComplaintController {

    private final ComplaintService service;

    public ComplaintController(ComplaintService service) {
        this.service = service;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ComplaintResponse raise(@AuthenticationPrincipal Long userId, @Valid @RequestBody ComplaintRequest request) {
        return service.raise(userId, request);
    }

    @GetMapping("/my")
    public List<ComplaintResponse> mine(@AuthenticationPrincipal Long userId) {
        return service.mine(userId);
    }
}
