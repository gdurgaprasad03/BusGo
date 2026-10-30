package com.example.busbooking.service;

import com.example.busbooking.dto.UpdateProfileRequest;
import com.example.busbooking.dto.UserResponse;
import com.example.busbooking.entity.User;
import com.example.busbooking.exception.ResourceNotFoundException;
import com.example.busbooking.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class UserService {

    private final UserRepository userRepository;

    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Transactional(readOnly = true)
    public UserResponse getProfile(Long userId) {
        return UserResponse.from(find(userId));
    }

    @Transactional
    public UserResponse updateProfile(Long userId, UpdateProfileRequest request) {
        User user = find(userId);
        user.setFullName(request.fullName().trim());
        user.setPhone(request.phone());
        return UserResponse.from(user); // saved automatically when the transaction commits (dirty checking)
    }

    private User find(Long userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
    }
}
