package com.luma.dto.request;

import com.luma.entity.enums.VerificationDocumentType;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.util.List;

@Data
public class SubmitVerificationRequest {

    @NotNull(message = "Document type is required")
    private VerificationDocumentType documentType;

    @NotEmpty(message = "At least one document image is required")
    @Size(max = 4, message = "Maximum 4 document images allowed")
    private List<String> documentUrls;

    private String legalName;

    private String documentNumber;
}
