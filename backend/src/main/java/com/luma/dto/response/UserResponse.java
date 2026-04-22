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
    private String bio;
    private String interests;
    private boolean networkingVisible;
    private LocalDateTime createdAt;
    private LocalDateTime lastLoginAt;

    public static UserResponse fromEntity(User user) {
        return UserResponse.builder()
                .id(user.getId())
                .email(user.getEmail())
                .phone(user.getPhone())
                .fullName(user.getFullName())
                .avatarUrl(resolveUserImageUrl(user))
                .signatureUrl(user.getSignatureUrl())
                .role(user.getRole())
                .status(user.getStatus())
                .phoneVerified(user.isPhoneVerified())
                .emailVerified(user.isEmailVerified())
                .emailNotificationsEnabled(user.isEmailNotificationsEnabled())
                .emailEventReminders(user.isEmailEventReminders())
                .bio(user.getBio())
                .interests(user.getInterests())
                .networkingVisible(user.isNetworkingVisible())
                .createdAt(user.getCreatedAt())
                .lastLoginAt(user.getLastLoginAt())
                .build();
    }

    private static String resolveUserImageUrl(User user) {
        if (user == null) {
            return null;
        }

        if (user.getOrganiserProfile() != null
                && user.getOrganiserProfile().getLogoUrl() != null
                && !user.getOrganiserProfile().getLogoUrl().isBlank()) {
            return user.getOrganiserProfile().getLogoUrl();
        }

        if (user.getAvatarUrl() != null && !user.getAvatarUrl().isBlank()) {
            return user.getAvatarUrl();
        }

        return null;
    }
}
