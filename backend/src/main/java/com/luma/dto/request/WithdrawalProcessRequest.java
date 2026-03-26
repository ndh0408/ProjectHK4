package com.luma.dto.request;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * DTO for admin to process (approve/reject) a withdrawal request
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class WithdrawalProcessRequest {

    private String adminNote;
}
