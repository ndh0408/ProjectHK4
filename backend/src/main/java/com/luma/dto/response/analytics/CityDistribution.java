package com.luma.dto.response.analytics;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CityDistribution {
    private Integer cityId;
    private String cityName;
    private String country;
    private long eventCount;
    private double percentage;
}
