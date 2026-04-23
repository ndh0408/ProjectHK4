package com.luma.dto.request;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.util.List;

/**
 * Public application to become an organiser.
 * Requires a Citizen ID (CCCD) to verify the applicant's identity.
 * The Verified badge is granted separately via a Business Licence submission
 * from the organiser profile after approval.
 */
@Data
public class ApplyOrganiserRequest {

    @NotBlank(message = "Full name is required")
    @Size(max = 200, message = "Full name must be at most 200 characters")
    private String fullName;

    @NotBlank(message = "Email is required")
    @Email(message = "Invalid email format")
    private String email;

    @NotBlank(message = "Password is required")
    @Size(min = 8, max = 100, message = "Password must be 8-100 characters")
    private String password;

    @Size(max = 50)
    private String phone;

    @NotBlank(message = "Organisation name is required")
    @Size(max = 200)
    private String organisationName;

    @Size(max = 2000)
    private String organisationBio;

    @Size(max = 500)
    private String organisationWebsite;

    @Email(message = "Invalid contact email")
    @Size(max = 200)
    private String organisationContactEmail;

    @Size(max = 50)
    private String organisationContactPhone;

    @NotEmpty(message = "Please upload your Citizen ID (front and back)")
    @Size(min = 1, max = 2, message = "Upload 1 or 2 Citizen ID images")
    private List<String> documentUrls;

    @Size(max = 200)
    private String legalName;

    @Size(max = 100)
    private String documentNumber;
}
