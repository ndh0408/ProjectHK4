package com.luma.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * DTO for admin to reject a withdrawal request
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class WithdrawalRejectRequest {

    @NotBlank(message = "Rejection reason is required")
    private String reason;
}
