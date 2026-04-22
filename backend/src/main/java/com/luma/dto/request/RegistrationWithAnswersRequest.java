package com.luma.dto.request;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.Data;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@Data
public class RegistrationWithAnswersRequest {
    private List<RegistrationAnswerRequest> answers;

    private UUID ticketTypeId;

    @Min(value = 1, message = "Quantity must be at least 1")
    @Max(value = 100, message = "Quantity cannot exceed 100 per registration")
    private Integer quantity = 1;

    /**
     * Optional professional profile submitted with the registration form:
     * jobTitle, company, industry, experienceLevel, registrationGoals,
     * expectations, linkedinUrl.
     * Persisted to User (jobTitle/company/industry/linkedinUrl) and
     * Registration (goals/expectations/experienceLevel) so organisers and
     * the AI review service can see the applicant's intent.
     */
    private Map<String, String> profileData;
}
