package com.luma.controller.user;

import com.luma.dto.response.ApiResponse;
import com.luma.dto.response.EventResponse;
import com.luma.dto.response.PageResponse;
import com.luma.entity.User;
import com.luma.service.BookmarkService;
import com.luma.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/user/bookmarks")
@RequiredArgsConstructor
@Tag(name = "User Bookmarks", description = "APIs for managing event bookmarks")
public class UserBookmarkController {

    private final BookmarkService bookmarkService;
    private final UserService userService;

    @PostMapping("/{eventId}")
    @Operation(summary = "Toggle bookmark for an event")
    public ResponseEntity<ApiResponse<Map<String, Boolean>>> toggleBookmark(
            @PathVariable UUID eventId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        boolean isBookmarked = bookmarkService.toggleBookmark(eventId, user);
        return ResponseEntity.ok(ApiResponse.success(Map.of("bookmarked", isBookmarked)));
    }

    @PostMapping("/{eventId}/add")
    @Operation(summary = "Add bookmark for an event")
    public ResponseEntity<ApiResponse<Void>> addBookmark(
            @PathVariable UUID eventId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        bookmarkService.addBookmark(eventId, user);
        return ResponseEntity.ok(ApiResponse.success(null));
    }

    @DeleteMapping("/{eventId}")
    @Operation(summary = "Remove bookmark for an event")
    public ResponseEntity<ApiResponse<Void>> removeBookmark(
            @PathVariable UUID eventId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        bookmarkService.removeBookmark(eventId, user);
        return ResponseEntity.ok(ApiResponse.success(null));
    }

    @GetMapping("/{eventId}/status")
    @Operation(summary = "Check if event is bookmarked")
    public ResponseEntity<ApiResponse<Map<String, Boolean>>> isBookmarked(
            @PathVariable UUID eventId,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        boolean isBookmarked = bookmarkService.isBookmarked(eventId, user);
        return ResponseEntity.ok(ApiResponse.success(Map.of("bookmarked", isBookmarked)));
    }

    @GetMapping
    @Operation(summary = "Get all bookmarked events")
    public ResponseEntity<ApiResponse<PageResponse<EventResponse>>> getBookmarkedEvents(
            @AuthenticationPrincipal UserDetails userDetails,
            @PageableDefault(size = 20) Pageable pageable) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(bookmarkService.getBookmarkedEvents(user, pageable)));
    }

    @GetMapping("/ids")
    @Operation(summary = "Get all bookmarked event IDs")
    public ResponseEntity<ApiResponse<List<UUID>>> getBookmarkedEventIds(
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(bookmarkService.getBookmarkedEventIds(user)));
    }

    @GetMapping("/count")
    @Operation(summary = "Get bookmark count")
    public ResponseEntity<ApiResponse<Map<String, Long>>> getBookmarkCount(
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userService.getEntityByEmail(userDetails.getUsername());
        long count = bookmarkService.countUserBookmarks(user);
        return ResponseEntity.ok(ApiResponse.success(Map.of("count", count)));
    }
}
