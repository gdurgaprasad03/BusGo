package com.example.busbooking.entity;

import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

import java.time.LocalDateTime;

/** Traveller details a user saved so they do not have to retype them for every booking. */
@Entity
@Table(name = "saved_passengers")
public class SavedPassenger {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id")
    private User user;

    private String name;
    private int age;
    private String gender;
    private LocalDateTime createdAt;

    protected SavedPassenger() {
    }

    public SavedPassenger(User user, String name, int age, String gender) {
        this.user = user;
        this.name = name;
        this.age = age;
        this.gender = gender;
        this.createdAt = LocalDateTime.now();
    }

    public Long getId() { return id; }
    public User getUser() { return user; }
    public String getName() { return name; }
    public int getAge() { return age; }
    public String getGender() { return gender; }
}
