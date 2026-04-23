package com.luma.dto.response;

import com.luma.entity.enums.QrLoginChallengeStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class QrLoginStatusResponse {

    private UUID challengeId;
    private QrLoginChallengeStatus status;
    private Instant expiresAt;
    private long expiresInSeconds;
    private String approvedByName;
    private Instant approvedAt;
}
