package com.luma.dto.response;

import com.luma.entity.User;
import com.luma.entity.enums.UserRole;
import com.luma.entity.enums.UserStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserResponse {
    
    private UUID id;
    private String email;
    private String phone;
    private String fullName;
    private String avatarUrl;
    private String signatureUrl;
    private UserRole role;
    private UserStatus status;
    private boolean phoneVerified;
    private boolean emailVerified;
    private boolean emailNotificationsEnabled;
    private boolean emailEventReminders;
    private LocalDateTime createdAt;
    private LocalDateTime lastLoginAt;

    public static UserResponse fromEntity(User user) {
        return UserResponse.builder()
                .id(user.getId())
                .email(user.getEmail())
                .phone(user.getPhone())
                .fullName(user.getFullName())
                .avatarUrl(user.getAvatarUrl())
                .signatureUrl(user.getSignatureUrl())
                .role(user.getRole())
                .status(user.getStatus())
                .phoneVerified(user.isPhoneVerified())
                .emailVerified(user.isEmailVerified())
                .emailNotificationsEnabled(user.isEmailNotificationsEnabled())
                .emailEventReminders(user.isEmailEventReminders())
                .createdAt(user.getCreatedAt())
                .lastLoginAt(user.getLastLoginAt())
                .build();
    }
}
