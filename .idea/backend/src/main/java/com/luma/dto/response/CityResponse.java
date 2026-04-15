package com.luma.dto.response;

import com.luma.entity.City;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CityResponse {

    private Long id;
    private String name;
    private String country;
    private String continent;
    private String imageUrl;
    private Double latitude;
    private Double longitude;
    private boolean active;
    private int eventCount;

    public static CityResponse fromEntity(City city) {
        return CityResponse.builder()
                .id(city.getId())
                .name(city.getName())
                .country(city.getCountry())
                .continent(city.getContinent())
                .imageUrl(city.getImageUrl())
                .latitude(city.getLatitude())
                .longitude(city.getLongitude())
                .active(city.isActive())
                .eventCount(city.getEvents() != null ? city.getEvents().size() : 0)
                .build();
    }
}
