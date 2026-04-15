package com.luma.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class CityRequest {

    @NotBlank(message = "City name is required")
    private String name;

    @NotBlank(message = "Country is required")
    private String country;

    @NotBlank(message = "Continent is required")
    private String continent;

    private String imageUrl;

    private Double latitude;

    private Double longitude;

    private Boolean active;
}
