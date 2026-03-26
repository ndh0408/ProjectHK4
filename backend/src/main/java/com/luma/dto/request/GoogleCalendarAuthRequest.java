package com.luma.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GoogleCalendarAuthRequest {

    @NotBlank(message = "Authorization code is required")
    private String code;

    private String redirectUri;
}
