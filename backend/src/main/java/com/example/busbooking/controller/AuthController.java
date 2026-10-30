package com.example.busbooking.controller;

import com.example.busbooking.dto.AuthConfigResponse;
import com.example.busbooking.dto.AuthResponse;
import com.example.busbooking.dto.ForgotPasswordRequest;
import com.example.busbooking.dto.GoogleLoginRequest;
import com.example.busbooking.dto.LoginRequest;
import com.example.busbooking.dto.RegisterRequest;
import com.example.busbooking.dto.ResetPasswordRequest;
import com.example.busbooking.service.AuthService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Controllers only translate HTTP <-> Java. Business rules live in the service. */
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/register")
    @ResponseStatus(HttpStatus.CREATED)
    public AuthResponse register(@Valid @RequestBody RegisterRequest request) {
        return authService.register(request);
    }

    @PostMapping("/login")
    public AuthResponse login(@Valid @RequestBody LoginRequest request) {
        return authService.login(request);
    }

    /** Google sign-in: the app sends the ID token it got from Google; the server verifies it. */
    @PostMapping("/google")
    public AuthResponse google(@Valid @RequestBody GoogleLoginRequest request) {
        return authService.googleLogin(request.idToken());
    }

    /** Tells the app which sign-in methods are available on this server. */
    @GetMapping("/config")
    public AuthConfigResponse config() {
        return authService.config();
    }

    /** Step 1 of "forgot password": emails a one-time code. The answer is always the same, registered or not. */
    @PostMapping("/forgot-password")
    public java.util.Map<String, Object> forgotPassword(@Valid @RequestBody ForgotPasswordRequest request) {
        authService.forgotPassword(request.email());
        return java.util.Map.of("message",
                "If that email is registered, we have sent a 6-digit code. It expires in a few minutes.");
    }

    /** Step 2: the emailed code plus the new password. */
    @PostMapping("/reset-password")
    public java.util.Map<String, String> resetPassword(@Valid @RequestBody ResetPasswordRequest request) {
        authService.resetPassword(request);
        return java.util.Map.of("message", "Password updated. You can now log in with your new password.");
    }
}