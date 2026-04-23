package com.luma.dto.response;

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
public class QrLoginChallengeResponse {

    private UUID challengeId;
    private String qrData;
    private String pollingToken;
    private Instant expiresAt;
    private long expiresInSeconds;
}
