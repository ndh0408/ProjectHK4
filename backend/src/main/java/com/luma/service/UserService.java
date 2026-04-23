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
import java.util.concurrent.ThreadLocalRandom;

@Service
@RequiredArgsConstructor
public class UserService {

    public static final int OTP_EXPIRY_MINUTES = 10;
    public static final int OTP_RESEND_COOLDOWN_SECONDS = 60;

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final EmailService emailService;

    @Transactional(readOnly = true)
    public User getEntityById(UUID id) {
        return userRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
    }

    @Transactional(readOnly = true)
    public User getEntityByEmail(String email) {
        return userRepository.findByEmail(email)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
    }

    @Transactional(readOnly = true)
    public UserResponse getUserById(UUID id) {
        return UserResponse.fromEntity(getEntityById(id));
    }

    @Transactional(readOnly = true)
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

        User.UserBuilder builder = User.builder()
                .email(request.getEmail())
                .phone(request.getPhone())
                .password(passwordEncoder.encode(request.getPassword()))
                .fullName(request.getFullName())
                .role(UserRole.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(false);

        String plainOtp = null;
        if (request.getEmail() != null) {
            plainOtp = generateOtp();
            builder.verificationCode(passwordEncoder.encode(plainOtp))
                    .verificationCodeExpiry(LocalDateTime.now().plusMinutes(OTP_EXPIRY_MINUTES));
        }

        User user = userRepository.save(builder.build());

        if (plainOtp != null) {
            emailService.sendOtpEmail(user.getEmail(), user.getFullName(), plainOtp, OTP_EXPIRY_MINUTES);
        }

        return user;
    }

    /**
     * Regenerate and email a fresh OTP. Enforces a cooldown so a user who
     * spams "resend" cannot flood their inbox or exhaust our SMTP quota.
     */
    @Transactional
    public void issueOtp(String email) {
        User user = getEntityByEmail(email);

        if (user.isEmailVerified()) {
            throw new BadRequestException("This email is already verified");
        }
        if (user.getEmail() == null) {
            throw new BadRequestException("No email on file for this account");
        }

        if (user.getVerificationCodeExpiry() != null) {
            LocalDateTime lastIssuedAt = user.getVerificationCodeExpiry()
                    .minusMinutes(OTP_EXPIRY_MINUTES);
            long secondsSinceIssue = java.time.Duration
                    .between(lastIssuedAt, LocalDateTime.now())
                    .getSeconds();
            if (secondsSinceIssue >= 0 && secondsSinceIssue < OTP_RESEND_COOLDOWN_SECONDS) {
                long wait = OTP_RESEND_COOLDOWN_SECONDS - secondsSinceIssue;
                throw new BadRequestException(
                        "Please wait " + wait + " seconds before requesting a new code");
            }
        }

        String plainOtp = generateOtp();
        user.setVerificationCode(passwordEncoder.encode(plainOtp));
        user.setVerificationCodeExpiry(LocalDateTime.now().plusMinutes(OTP_EXPIRY_MINUTES));
        userRepository.save(user);

        emailService.sendOtpEmail(user.getEmail(), user.getFullName(), plainOtp, OTP_EXPIRY_MINUTES);
    }

    @Transactional
    public User confirmOtp(String email, String otp) {
        User user = getEntityByEmail(email);

        if (user.isEmailVerified()) {
            return user;
        }

        if (user.getVerificationCode() == null || user.getVerificationCodeExpiry() == null) {
            throw new BadRequestException("No verification code found. Please request a new one.");
        }

        if (user.getVerificationCodeExpiry().isBefore(LocalDateTime.now())) {
            throw new BadRequestException("Verification code has expired. Please request a new one.");
        }

        if (!passwordEncoder.matches(otp, user.getVerificationCode())) {
            throw new BadRequestException("Invalid verification code");
        }

        user.setEmailVerified(true);
        user.setVerificationCode(null);
        user.setVerificationCodeExpiry(null);
        return userRepository.save(user);
    }

    private String generateOtp() {
        return String.format("%06d", ThreadLocalRandom.current().nextInt(1_000_000));
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
        if (request.getBio() != null) {
            user.setBio(request.getBio());
        }
        if (request.getInterests() != null) {
            user.setInterests(request.getInterests());
        }
        if (request.getNetworkingVisible() != null) {
            user.setNetworkingVisible(request.getNetworkingVisible());
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

    @Transactional(readOnly = true)
    public PageResponse<UserResponse> getAllUsers(Pageable pageable) {
        Page<User> users = userRepository.findAll(pageable);
        return PageResponse.from(users, UserResponse::fromEntity);
    }

    @Transactional(readOnly = true)
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

    @Transactional(readOnly = true)
    public long countByRole(UserRole role) {
        return userRepository.countByRole(role);
    }

    @Transactional(readOnly = true)
    public long countNewUsersInMonth(int month, int year) {
        return userRepository.countNewUsersInMonth(month, year);
    }
}
