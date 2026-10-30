package com.example.busbooking.service;

import com.example.busbooking.dto.AuthConfigResponse;
import com.example.busbooking.dto.AuthResponse;
import com.example.busbooking.dto.LoginRequest;
import com.example.busbooking.dto.RegisterRequest;
import com.example.busbooking.dto.ResetPasswordRequest;
import com.example.busbooking.dto.UserResponse;
import com.example.busbooking.entity.PasswordResetCode;
import com.example.busbooking.entity.User;
import com.example.busbooking.exception.ApiException;
import com.example.busbooking.exception.BadRequestException;
import com.example.busbooking.exception.ConflictException;
import com.example.busbooking.exception.UnauthorizedException;
import com.example.busbooking.mail.EmailTemplates;
import com.example.busbooking.mail.Mailer;
import com.example.busbooking.repository.PasswordResetCodeRepository;
import com.example.busbooking.repository.UserRepository;
import com.example.busbooking.security.GoogleIdentity;
import com.example.busbooking.security.GoogleTokenVerifier;
import com.example.busbooking.security.JwtService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.Base64;
import java.util.List;

/** Registration, login, Google sign-in and password reset. Passwords are only ever stored as BCrypt hashes. */
@Service
public class AuthService {

    /** Same answer for "no such email", "wrong code", "expired" and "too many tries", so nothing can be probed. */
    static final String BAD_CODE_MESSAGE = "This code is invalid or has expired. Please request a new one.";

    private final UserRepository userRepository;
    private final PasswordResetCodeRepository resetCodeRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final GoogleTokenVerifier googleTokenVerifier;
    private final Mailer mailer;
    private final int resetExpiryMinutes;
    private final int resetMaxAttempts;
    private final int resetResendSeconds;
    private final SecureRandom random = new SecureRandom();

    // Constructor injection: Spring passes in the beans it manages.
    public AuthService(UserRepository userRepository, PasswordResetCodeRepository resetCodeRepository,
                       PasswordEncoder passwordEncoder, JwtService jwtService, GoogleTokenVerifier googleTokenVerifier,
                       Mailer mailer,
                       @Value("${app.password-reset.expiry-minutes:15}") int resetExpiryMinutes,
                       @Value("${app.password-reset.max-attempts:5}") int resetMaxAttempts,
                       @Value("${app.password-reset.resend-seconds:60}") int resetResendSeconds) {
        this.userRepository = userRepository;
        this.resetCodeRepository = resetCodeRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.googleTokenVerifier = googleTokenVerifier;
        this.mailer = mailer;
        this.resetExpiryMinutes = resetExpiryMinutes;
        this.resetMaxAttempts = resetMaxAttempts;
        this.resetResendSeconds = resetResendSeconds;
    }

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        String email = request.email().trim().toLowerCase();
        if (userRepository.existsByEmailIgnoreCase(email)) {
            throw new ConflictException("An account with this email already exists");
        }
        User user = userRepository.save(new User(request.fullName().trim(), email, request.phone(),
                passwordEncoder.encode(request.password())));
        mailer.queue(EmailTemplates.welcome(user.getEmail(), user.getFullName()));
        return new AuthResponse(jwtService.createToken(user.getId()), UserResponse.from(user));
    }

    @Transactional(readOnly = true)
    public AuthResponse login(LoginRequest request) {
        String identifier = request.identifier().trim();
        // Same message for unknown account and wrong password, so attackers cannot probe for accounts.
        User user = findCandidates(identifier).stream()
                .filter(u -> passwordEncoder.matches(request.password(), u.getPasswordHash()))
                .findFirst()
                .orElseThrow(() -> new UnauthorizedException("Invalid email/mobile number or password"));
        return new AuthResponse(jwtService.createToken(user.getId()), UserResponse.from(user));
    }

    /** Which optional features this server has been configured for. */
    public AuthConfigResponse config() {
        return new AuthConfigResponse(googleTokenVerifier.isConfigured(), mailer.isDeliveryEnabled());
    }

    /**
     * Google sign-in. The server verifies the ID token with Google first; the email and name in the request body
     * are never used. The account is matched by Google's stable id (the "sub" claim), not by email.
     *
     * If a normal (password) account with the same email already exists we do NOT link it automatically:
     * emails are not verified when registering, so someone could have registered with another person's email
     * and then wait for that person to sign in with Google. Such users must log in with their password.
     */
    @Transactional
    public AuthResponse googleLogin(String idToken) {
        GoogleIdentity identity = googleTokenVerifier.verify(idToken);
        User user = userRepository.findByGoogleSub(identity.subject()).orElse(null);
        if (user == null) {
            if (userRepository.existsByEmailIgnoreCase(identity.email())) {
                throw new ConflictException(
                        "An account with this email already exists. Please log in with your email and password.");
            }
            String name = identity.name().isBlank() ? identity.email().substring(0, identity.email().indexOf('@')) : identity.name();
            user = userRepository.save(User.fromGoogle(name, identity.email(), identity.subject(),
                    passwordEncoder.encode(randomSecret())));
            mailer.queue(EmailTemplates.welcome(user.getEmail(), user.getFullName()));
        }
        return new AuthResponse(jwtService.createToken(user.getId()), UserResponse.from(user));
    }

    /**
     * Step 1 of "forgot password": email a 6-digit one-time code. The caller always gets the same answer whether or not
     * the email is registered (so the endpoint cannot be used to find out who has an account). Only a hash of the code is
     * stored; it expires, works once and allows a few wrong guesses. Asking again within a minute is ignored.
     */
    @Transactional
    public void forgotPassword(String rawEmail) {
        userRepository.findByEmailIgnoreCase(rawEmail.trim()).ifPresent(user -> {
            LocalDateTime now = LocalDateTime.now();
            boolean tooSoon = resetCodeRepository.findFirstByUserIdOrderByCreatedAtDescIdDesc(user.getId())
                    .map(last -> last.getCreatedAt().plusSeconds(resetResendSeconds).isAfter(now))
                    .orElse(false);
            if (tooSoon) {
                return;
            }
            resetCodeRepository.deleteAll(resetCodeRepository.findByUserId(user.getId())); // only the newest code works
            String code = String.format("%06d", random.nextInt(1_000_000));
            resetCodeRepository.save(new PasswordResetCode(user.getId(), passwordEncoder.encode(code),
                    now.plusMinutes(resetExpiryMinutes)));
            mailer.queue(EmailTemplates.resetCode(user.getEmail(), user.getFullName(), code, resetExpiryMinutes));
        });
    }

    /**
     * Step 2: check the emailed code and set the new password. noRollbackFor keeps the "wrong guess" counter even though
     * an exception is thrown, which is what makes the attempt limit work.
     */
    @Transactional(noRollbackFor = ApiException.class)
    public void resetPassword(ResetPasswordRequest request) {
        User user = userRepository.findByEmailIgnoreCase(request.email().trim())
                .orElseThrow(() -> new BadRequestException(BAD_CODE_MESSAGE));
        PasswordResetCode code = resetCodeRepository.findFirstByUserIdOrderByCreatedAtDescIdDesc(user.getId())
                .orElseThrow(() -> new BadRequestException(BAD_CODE_MESSAGE));
        if (!code.isUsable(LocalDateTime.now(), resetMaxAttempts)) {
            throw new BadRequestException(BAD_CODE_MESSAGE);
        }
        if (!passwordEncoder.matches(request.code(), code.getCodeHash())) {
            code.recordWrongGuess();
            throw new BadRequestException(BAD_CODE_MESSAGE);
        }
        code.markUsed();
        user.setPasswordHash(passwordEncoder.encode(request.newPassword()));
        mailer.queue(EmailTemplates.passwordChanged(user.getEmail(), user.getFullName()));
    }

    /** An identifier with "@" is an email; otherwise it is treated as a mobile number. */
    private List<User> findCandidates(String identifier) {
        if (identifier.contains("@")) {
            return userRepository.findByEmailIgnoreCase(identifier).map(List::of).orElse(List.of());
        }
        return userRepository.findByPhone(identifier);
    }

    private String randomSecret() {
        byte[] bytes = new byte[32];
        random.nextBytes(bytes);
        return Base64.getEncoder().encodeToString(bytes);
    }
}
