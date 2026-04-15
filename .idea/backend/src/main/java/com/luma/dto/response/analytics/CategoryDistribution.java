package com.luma.dto.response.analytics;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CategoryDistribution {
    private Integer categoryId;
    private String categoryName;
    private long eventCount;
    private long registrationCount;
    private double percentage;
}
