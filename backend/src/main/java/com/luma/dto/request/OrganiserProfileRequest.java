package com.luma.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class OrganiserProfileRequest {

    @NotBlank(message = "Display name is required")
    private String displayName;

    private String bio;

    private String logoUrl;

    private String website;

    private String contactEmail;

    private String contactPhone;
}
