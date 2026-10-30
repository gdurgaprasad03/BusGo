package com.example.busbooking.dto;

import com.example.busbooking.entity.User;

/** What the API reveals about a user. Note: no password hash. */
public record UserResponse(Long id, String fullName, String email, String phone) {

    public static UserResponse from(User user) {
        return new UserResponse(user.getId(), user.getFullName(), user.getEmail(), user.getPhone());
    }
}
