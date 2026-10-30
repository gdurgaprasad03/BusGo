package com.example.busbooking.controller;

import com.example.busbooking.dto.UpdateProfileRequest;
import com.example.busbooking.dto.UserResponse;
import com.example.busbooking.service.UserService;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/users")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    // @AuthenticationPrincipal injects the user id that JwtAuthenticationFilter put into the security context.
    @GetMapping("/me")
    public UserResponse me(@AuthenticationPrincipal Long userId) {
        return userService.getProfile(userId);
    }

    @PutMapping("/me")
    public UserResponse update(@AuthenticationPrincipal Long userId, @Valid @RequestBody UpdateProfileRequest request) {
        return userService.updateProfile(userId, request);
    }
}
