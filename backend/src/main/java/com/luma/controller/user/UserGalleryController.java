package com.luma.controller.user;

import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.EventImageResponse;
import com.luma.service.EventImageService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/user/gallery")
@RequiredArgsConstructor
public class UserGalleryController {

    private final EventImageService eventImageService;

    @GetMapping
    public ResponseEntity<ApiResponse<Page<EventImageResponse>>> getGalleryImages(
            @PageableDefault(size = 20, sort = "createdAt", direction = Sort.Direction.DESC) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(eventImageService.getGalleryImages(pageable)));
    }

    @GetMapping("/category/{categoryId}")
    public ResponseEntity<ApiResponse<Page<EventImageResponse>>> getGalleryImagesByCategory(
            @PathVariable Long categoryId,
            @PageableDefault(size = 20, sort = "createdAt", direction = Sort.Direction.DESC) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(eventImageService.getGalleryImagesByCategory(categoryId, pageable)));
    }

    @GetMapping("/event/{eventId}")
    public ResponseEntity<ApiResponse<EventImageResponse>> getEventImage(@PathVariable UUID eventId) {
        return ResponseEntity.ok(ApiResponse.success(eventImageService.getEventImage(eventId)));
    }
}
