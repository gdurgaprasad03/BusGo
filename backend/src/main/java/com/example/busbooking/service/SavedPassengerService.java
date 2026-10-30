package com.example.busbooking.service;

import com.example.busbooking.dto.SavedPassengerRequest;
import com.example.busbooking.dto.SavedPassengerResponse;
import com.example.busbooking.entity.SavedPassenger;
import com.example.busbooking.exception.BadRequestException;
import com.example.busbooking.exception.ConflictException;
import com.example.busbooking.exception.ForbiddenException;
import com.example.busbooking.exception.ResourceNotFoundException;
import com.example.busbooking.repository.SavedPassengerRepository;
import com.example.busbooking.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class SavedPassengerService {

    static final int MAX_PER_USER = 10;

    private final SavedPassengerRepository repository;
    private final UserRepository userRepository;

    public SavedPassengerService(SavedPassengerRepository repository, UserRepository userRepository) {
        this.repository = repository;
        this.userRepository = userRepository;
    }

    @Transactional(readOnly = true)
    public List<SavedPassengerResponse> list(Long userId) {
        return repository.findByUserIdOrderByCreatedAtDesc(userId).stream().map(SavedPassengerResponse::from).toList();
    }

    @Transactional
    public SavedPassengerResponse add(Long userId, SavedPassengerRequest request) {
        String name = request.name().trim();
        if (repository.existsByUserIdAndNameIgnoreCaseAndAgeAndGender(userId, name, request.age(), request.gender())) {
            throw new ConflictException("This passenger is already saved");
        }
        if (repository.countByUserId(userId) >= MAX_PER_USER) {
            throw new BadRequestException("You can save at most " + MAX_PER_USER + " passengers. Delete one first.");
        }
        var user = userRepository.findById(userId).orElseThrow(() -> new ResourceNotFoundException("User not found"));
        return SavedPassengerResponse.from(repository.save(new SavedPassenger(user, name, request.age(), request.gender())));
    }

    @Transactional
    public void delete(Long userId, Long passengerId) {
        SavedPassenger p = repository.findById(passengerId)
                .orElseThrow(() -> new ResourceNotFoundException("Saved passenger not found"));
        if (!p.getUser().getId().equals(userId)) {
            throw new ForbiddenException("You do not have access to this passenger");
        }
        repository.delete(p);
    }
}
