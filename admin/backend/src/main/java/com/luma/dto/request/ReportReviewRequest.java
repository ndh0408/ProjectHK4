package com.luma.dto.request;

import com.luma.entity.enums.ReportReason;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class ReportReviewRequest {

    @NotNull(message = "Reason is required")
    private ReportReason reason;

    @Size(max = 500, message = "Description must not exceed 500 characters")
    private String description;
}
