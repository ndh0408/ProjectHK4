package com.luma.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PendingVerificationResponse {

    private String email;

    @Builder.Default
    private boolean needsVerification = true;

    private int otpExpiresInSeconds;
}
