package com.luma.dto.request;

import com.luma.entity.enums.ReportStatus;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class ResolveReportRequest {

    @NotNull(message = "Status is required")
    private ReportStatus status;

    @Size(max = 500, message = "Note must not exceed 500 characters")
    private String note;
}
