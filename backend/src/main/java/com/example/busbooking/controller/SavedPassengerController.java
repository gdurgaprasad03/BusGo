package com.example.busbooking.controller;

import com.example.busbooking.dto.SavedPassengerRequest;
import com.example.busbooking.dto.SavedPassengerResponse;
import com.example.busbooking.service.SavedPassengerService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/** The logged-in user's saved passengers. */
@RestController
@RequestMapping("/api/users/me/passengers")
public class SavedPassengerController {

    private final SavedPassengerService service;

    public SavedPassengerController(SavedPassengerService service) {
        this.service = service;
    }

    @GetMapping
    public List<SavedPassengerResponse> list(@AuthenticationPrincipal Long userId) {
        return service.list(userId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public SavedPassengerResponse add(@AuthenticationPrincipal Long userId,
                                      @Valid @RequestBody SavedPassengerRequest request) {
        return service.add(userId, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@AuthenticationPrincipal Long userId, @PathVariable Long id) {
        service.delete(userId, id);
    }
}
