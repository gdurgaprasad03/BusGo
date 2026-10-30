package com.example.busbooking.entity;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.LocalDateTime;

/** A registered customer. Maps to the "users" table. */
@Entity
@Table(name = "users")
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String fullName;
    private String email;
    private String phone; // optional: accounts created with Google sign-in have no phone until the user adds one
    private String passwordHash;
    private LocalDateTime createdAt;
    private String googleSub; // Google's unique id for this person, set only for Google sign-in accounts

    protected User() {
        // required by JPA
    }

    public User(String fullName, String email, String phone, String passwordHash) {
        this.fullName = fullName;
        this.email = email;
        this.phone = phone;
        this.passwordHash = passwordHash;
        this.createdAt = LocalDateTime.now();
    }

    /** An account created through Google sign-in. Its password hash is random and can never be used to log in. */
    public static User fromGoogle(String fullName, String email, String googleSub, String unusablePasswordHash) {
        User user = new User(fullName, email, null, unusablePasswordHash);
        user.googleSub = googleSub;
        return user;
    }

    public Long getId() { return id; }
    public String getFullName() { return fullName; }
    public String getEmail() { return email; }
    public String getPhone() { return phone; }
    public String getPasswordHash() { return passwordHash; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public String getGoogleSub() { return googleSub; }

    public void setFullName(String fullName) { this.fullName = fullName; }
    public void setPhone(String phone) { this.phone = phone; }
    public void setPasswordHash(String passwordHash) { this.passwordHash = passwordHash; }
}
