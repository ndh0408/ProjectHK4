package com.luma.controller;

import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.CategoryResponse;
import com.luma.dto.response.CertificateResponse;
import com.luma.dto.response.CityResponse;
import com.luma.service.CategoryService;
import com.luma.service.CertificateService;
import com.luma.service.CityService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
@Tag(name = "Public", description = "Public APIs for categories and cities")
public class PublicController {

    private final CategoryService categoryService;
    private final CityService cityService;
    private final CertificateService certificateService;

    @GetMapping("/categories")
    @Operation(summary = "Get all categories (public)")
    public ResponseEntity<ApiResponse<List<CategoryResponse>>> getAllCategories() {
        return ResponseEntity.ok(ApiResponse.success(categoryService.getAllCategories()));
    }

    @GetMapping("/cities")
    @Operation(summary = "Get all cities (public)")
    public ResponseEntity<ApiResponse<List<CityResponse>>> getAllCities() {
        return ResponseEntity.ok(ApiResponse.success(cityService.getAllCities()));
    }

    @GetMapping("/cities/with-events")
    @Operation(summary = "Get cities that have events (public)")
    public ResponseEntity<ApiResponse<List<CityResponse>>> getCitiesWithEvents() {
        return ResponseEntity.ok(ApiResponse.success(cityService.getCitiesWithEvents()));
    }

    @GetMapping("/cities/by-continent")
    @Operation(summary = "Get cities with events grouped by continent (public)")
    public ResponseEntity<ApiResponse<Map<String, List<CityResponse>>>> getCitiesByContinent() {
        return ResponseEntity.ok(ApiResponse.success(cityService.getCitiesByContinent()));
    }

    @GetMapping("/certificates/verify/{code}")
    @Operation(summary = "Verify certificate by code (public)")
    public ResponseEntity<ApiResponse<CertificateResponse>> verifyCertificate(@PathVariable String code) {
        CertificateResponse response = certificateService.verifyCertificate(code);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/certificates/{code}/pdf")
    @Operation(summary = "View or download certificate PDF by code (public)")
    public ResponseEntity<byte[]> getCertificatePdf(
            @PathVariable String code,
            @RequestParam(defaultValue = "false") boolean download) {
        byte[] pdfBytes = certificateService.getCertificatePdfByCode(code);

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_PDF);

        if (download) {
            headers.setContentDispositionFormData("attachment", code + ".pdf");
        } else {
            headers.add(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"" + code + ".pdf\"");
        }

        return ResponseEntity.ok()
                .headers(headers)
                .body(pdfBytes);
    }
}
