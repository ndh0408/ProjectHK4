package com.luma.controller.admin;

import com.luma.dto.request.CityRequest;
import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.CityResponse;
import com.luma.service.CityService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/admin/cities")
@RequiredArgsConstructor
@Tag(name = "Admin Cities", description = "APIs for admin city management")
public class AdminCityController {

    private final CityService cityService;

    @GetMapping
    @Operation(summary = "Get all cities (including inactive)")
    public ResponseEntity<ApiResponse<List<CityResponse>>> getAllCities() {
        return ResponseEntity.ok(ApiResponse.success(cityService.getAllCitiesForAdmin()));
    }

    @GetMapping("/by-continent")
    @Operation(summary = "Get cities grouped by continent")
    public ResponseEntity<ApiResponse<Map<String, List<CityResponse>>>> getCitiesByContinent() {
        return ResponseEntity.ok(ApiResponse.success(cityService.getCitiesByContinent()));
    }

    @PostMapping
    @Operation(summary = "Create a new city")
    public ResponseEntity<ApiResponse<CityResponse>> createCity(@Valid @RequestBody CityRequest request) {
        return ResponseEntity.ok(ApiResponse.success("City created successfully", cityService.createCity(request)));
    }

    @PutMapping("/{cityId}")
    @Operation(summary = "Update a city")
    public ResponseEntity<ApiResponse<CityResponse>> updateCity(
            @PathVariable Long cityId,
            @Valid @RequestBody CityRequest request) {
        return ResponseEntity.ok(ApiResponse.success("City updated successfully", cityService.updateCity(cityId, request)));
    }

    @DeleteMapping("/{cityId}")
    @Operation(summary = "Delete a city")
    public ResponseEntity<ApiResponse<Void>> deleteCity(@PathVariable Long cityId) {
        cityService.deleteCity(cityId);
        return ResponseEntity.ok(ApiResponse.success("City deleted successfully", null));
    }
}
