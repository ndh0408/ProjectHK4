package com.luma.dto.response;

import com.luma.entity.BlockedUser;
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
public class BlockedUserResponse {

    private UUID id;
    private UUID userId;
    private String fullName;
    private String avatarUrl;
    private String reason;
    private LocalDateTime blockedAt;

    public static BlockedUserResponse fromEntity(BlockedUser blockedUser) {
        return BlockedUserResponse.builder()
                .id(blockedUser.getId())
                .userId(blockedUser.getBlocked().getId())
                .fullName(blockedUser.getBlocked().getFullName())
                .avatarUrl(blockedUser.getBlocked().getAvatarUrl())
                .reason(blockedUser.getReason())
                .blockedAt(blockedUser.getBlockedAt())
                .build();
    }
}
