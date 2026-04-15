package com.luma.dto.request;

import jakarta.validation.constraints.Min;
import lombok.Data;

import java.util.List;
import java.util.UUID;

@Data
public class RegistrationWithAnswersRequest {
    private List<RegistrationAnswerRequest> answers;

    private UUID ticketTypeId;

    @Min(value = 1, message = "Quantity must be at least 1")
    private Integer quantity = 1;
}
