package com.luma.dto.request;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class ReviewVerificationRequest {

    @NotNull(message = "Approve flag is required")
    private Boolean approve;

    /**
     * Two-tier trust model:
     * - approve=true, grantVerifiedBadge=false → Accept the applicant (role=ORGANISER) but NO Verified tick
     *   (used for individuals with only a CCCD, small organisers)
     * - approve=true, grantVerifiedBadge=true  → Accept AND grant the Verified tick
     *   (trusted brands with business licence, established organisations)
     * - approve=false → reject, rejectReason required
     */
    private Boolean grantVerifiedBadge;

    private String rejectReason;
}
