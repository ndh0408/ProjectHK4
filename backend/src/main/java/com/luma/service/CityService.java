package com.luma.service;

import com.luma.dto.request.CityRequest;
import com.luma.dto.response.CityResponse;
import com.luma.entity.City;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.CityRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CityService {

    private final CityRepository cityRepository;

    @Transactional(readOnly = true)
    public City getEntityById(Long id) {
        return cityRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("City not found"));
    }

    @Transactional(readOnly = true)
    public List<CityResponse> getAllCities() {
        return cityRepository.findByActiveTrue().stream()
                .map(CityResponse::fromEntity)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<CityResponse> getAllCitiesForAdmin() {
        return cityRepository.findAll().stream()
                .map(CityResponse::fromEntity)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<CityResponse> getCitiesWithEvents() {
        return cityRepository.findCitiesWithEvents().stream()
                .map(CityResponse::fromEntity)
                .toList();
    }

    @Transactional(readOnly = true)
    public Map<String, List<CityResponse>> getCitiesByContinent() {
        return cityRepository.findCitiesWithEvents().stream()
                .map(CityResponse::fromEntity)
                .collect(Collectors.groupingBy(CityResponse::getContinent));
    }

    @Transactional(readOnly = true)
    public CityResponse getCityById(Long id) {
        return CityResponse.fromEntity(getEntityById(id));
    }

    @Transactional
    public CityResponse createCity(CityRequest request) {
        City city = City.builder()
                .name(request.getName())
                .country(request.getCountry())
                .continent(request.getContinent())
                .imageUrl(request.getImageUrl())
                .latitude(request.getLatitude())
                .longitude(request.getLongitude())
                .active(true)
                .build();

        return CityResponse.fromEntity(cityRepository.save(city));
    }

    @Transactional
    public CityResponse updateCity(Long id, CityRequest request) {
        City city = getEntityById(id);

        city.setName(request.getName());
        city.setCountry(request.getCountry());
        city.setContinent(request.getContinent());
        city.setImageUrl(request.getImageUrl());
        city.setLatitude(request.getLatitude());
        city.setLongitude(request.getLongitude());
        if (request.getActive() != null) {
            city.setActive(request.getActive());
        }

        return CityResponse.fromEntity(cityRepository.save(city));
    }

    @Transactional
    public void deleteCity(Long id) {
        City city = getEntityById(id);
        if (city.getEvents() != null && !city.getEvents().isEmpty()) {
            throw new BadRequestException("Cannot delete city with existing events");
        }
        cityRepository.delete(city);
    }
}
