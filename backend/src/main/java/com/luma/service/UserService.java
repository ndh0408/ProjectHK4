package com.luma.service;

import com.luma.dto.request.ChangePasswordRequest;
import com.luma.dto.request.RegisterRequest;
import com.luma.dto.request.UpdateProfileRequest;
import com.luma.dto.response.PageResponse;
import com.luma.dto.response.UserResponse;
import com.luma.entity.User;
import com.luma.entity.enums.UserRole;
import com.luma.entity.enums.UserStatus;
import com.luma.exception.ResourceNotFoundException;
import com.luma.exception.BadRequestException;
import com.luma.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public User getEntityById(UUID id) {
        return userRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
    }

    public User getEntityByEmail(String email) {
        return userRepository.findByEmail(email)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
    }

    public UserResponse getUserById(UUID id) {
        return UserResponse.fromEntity(getEntityById(id));
    }

    public UserResponse getUserByEmail(String email) {
        return UserResponse.fromEntity(getEntityByEmail(email));
    }

    @Transactional
    public User createUser(RegisterRequest request) {
        if (request.getEmail() != null && userRepository.existsByEmail(request.getEmail())) {
            throw new BadRequestException("Email is already in use");
        }
        if (request.getPhone() != null && userRepository.existsByPhone(request.getPhone())) {
            throw new BadRequestException("Phone number is already in use");
        }

        User user = User.builder()
                .email(request.getEmail())
                .phone(request.getPhone())
                .password(passwordEncoder.encode(request.getPassword()))
                .fullName(request.getFullName())
                .role(UserRole.USER)
                .status(UserStatus.ACTIVE)
                .build();

        return userRepository.save(user);
    }

    @Transactional
    public UserResponse updateProfile(UUID userId, UpdateProfileRequest request) {
        User user = getEntityById(userId);

        if (request.getFullName() != null) {
            user.setFullName(request.getFullName());
        }
        if (request.getPhone() != null) {
            if (userRepository.existsByPhone(request.getPhone()) && 
                !request.getPhone().equals(user.getPhone())) {
                throw new BadRequestException("Phone number is already in use");
            }
            user.setPhone(request.getPhone());
        }
        if (request.getAvatarUrl() != null) {
            user.setAvatarUrl(request.getAvatarUrl());
        }
        if (request.getSignatureUrl() != null) {
            user.setSignatureUrl(request.getSignatureUrl());
        }
        if (request.getEmailNotificationsEnabled() != null) {
            user.setEmailNotificationsEnabled(request.getEmailNotificationsEnabled());
        }
        if (request.getEmailEventReminders() != null) {
            user.setEmailEventReminders(request.getEmailEventReminders());
        }

        return UserResponse.fromEntity(userRepository.save(user));
    }

    @Transactional
    public void changePassword(UUID userId, ChangePasswordRequest request) {
        User user = getEntityById(userId);

        if (!passwordEncoder.matches(request.getOldPassword(), user.getPassword())) {
            throw new BadRequestException("Current password is incorrect");
        }

        user.setPassword(passwordEncoder.encode(request.getNewPassword()));
        userRepository.save(user);
    }

    @Transactional
    public void updateLastLogin(UUID userId) {
        User user = getEntityById(userId);
        user.setLastLoginAt(LocalDateTime.now());
        userRepository.save(user);
    }

    public PageResponse<UserResponse> getAllUsers(Pageable pageable) {
        Page<User> users = userRepository.findAll(pageable);
        return PageResponse.from(users, UserResponse::fromEntity);
    }

    public PageResponse<UserResponse> searchUsers(String query, UserRole role, UserStatus status, Pageable pageable) {
        Page<User> users;
        if (query != null && !query.isEmpty()) {
            if (role != null) {
                users = userRepository.searchUsersByRole(query, role, pageable);
            } else {
                users = userRepository.searchUsersExcludeAdmin(query, pageable);
            }
        } else if (role != null && status != null) {
            users = userRepository.findByRoleAndStatus(role, status, pageable);
        } else if (role != null) {
            users = userRepository.findByRole(role, pageable);
        } else if (status != null) {
            users = userRepository.findByStatusAndRoleNot(status, UserRole.ADMIN, pageable);
        } else {
            users = userRepository.findByRoleNot(UserRole.ADMIN, pageable);
        }
        return PageResponse.from(users, UserResponse::fromEntity);
    }

    @Transactional
    public UserResponse updateUserRole(UUID userId, UserRole role) {
        User user = getEntityById(userId);
        if (user.getRole() == UserRole.ADMIN) {
            throw new BadRequestException("Cannot change role of admin account");
        }
        user.setRole(role);
        return UserResponse.fromEntity(userRepository.save(user));
    }

    @Transactional
    public UserResponse updateUserStatus(UUID userId, UserStatus status) {
        User user = getEntityById(userId);
        if (user.getRole() == UserRole.ADMIN) {
            throw new BadRequestException("Cannot change status of admin account");
        }
        user.setStatus(status);
        return UserResponse.fromEntity(userRepository.save(user));
    }

    @Transactional
    public UserResponse lockUser(UUID userId) {
        return updateUserStatus(userId, UserStatus.LOCKED);
    }

    @Transactional
    public UserResponse unlockUser(UUID userId) {
        return updateUserStatus(userId, UserStatus.ACTIVE);
    }

    @Transactional
    public void deleteUser(UUID userId) {
        User user = getEntityById(userId);
        if (user.getRole() == UserRole.ADMIN) {
            throw new BadRequestException("Cannot delete admin account");
        }
        userRepository.delete(user);
    }

    public long countByRole(UserRole role) {
        return userRepository.countByRole(role);
    }

    public long countNewUsersInMonth(int month, int year) {
        return userRepository.countNewUsersInMonth(month, year);
    }
}
