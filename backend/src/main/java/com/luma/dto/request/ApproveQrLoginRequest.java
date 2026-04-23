package com.luma.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ApproveQrLoginRequest {

    @NotBlank(message = "Challenge ID is required")
    private String challengeId;

    @NotBlank(message = "Approval code is required")
    private String approvalCode;
}
