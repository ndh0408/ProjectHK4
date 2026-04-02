package com.luma.service;

import com.luma.dto.response.EventResponse;
import com.luma.dto.response.PageResponse;
import com.luma.entity.Bookmark;
import com.luma.entity.Event;
import com.luma.entity.User;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.BookmarkRepository;
import com.luma.repository.EventRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class BookmarkService {

    private final BookmarkRepository bookmarkRepository;
    private final EventRepository eventRepository;

    @Transactional
    public boolean toggleBookmark(UUID eventId, User user) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));

        if (bookmarkRepository.existsByUserAndEvent(user, event)) {
            bookmarkRepository.deleteByUserAndEvent(user, event);
            log.info("User {} unbookmarked event {}", user.getId(), eventId);
            return false;
        } else {
            Bookmark bookmark = Bookmark.builder()
                    .user(user)
                    .event(event)
                    .build();
            bookmarkRepository.save(bookmark);
            log.info("User {} bookmarked event {}", user.getId(), eventId);
            return true;
        }
    }

    @Transactional
    public void addBookmark(UUID eventId, User user) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));

        if (!bookmarkRepository.existsByUserAndEvent(user, event)) {
            Bookmark bookmark = Bookmark.builder()
                    .user(user)
                    .event(event)
                    .build();
            bookmarkRepository.save(bookmark);
            log.info("User {} bookmarked event {}", user.getId(), eventId);
        }
    }

    @Transactional
    public void removeBookmark(UUID eventId, User user) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));

        bookmarkRepository.deleteByUserAndEvent(user, event);
        log.info("User {} unbookmarked event {}", user.getId(), eventId);
    }

    public boolean isBookmarked(UUID eventId, User user) {
        Event event = eventRepository.findById(eventId).orElse(null);
        if (event == null) return false;
        return bookmarkRepository.existsByUserAndEvent(user, event);
    }

    public PageResponse<EventResponse> getBookmarkedEvents(User user, Pageable pageable) {
        Page<Bookmark> bookmarks = bookmarkRepository.findByUser(user, pageable);

        return PageResponse.<EventResponse>builder()
                .content(bookmarks.map(b -> EventResponse.fromEntity(b.getEvent())).getContent())
                .page(bookmarks.getNumber())
                .size(bookmarks.getSize())
                .totalElements(bookmarks.getTotalElements())
                .totalPages(bookmarks.getTotalPages())
                .last(bookmarks.isLast())
                .build();
    }

    public List<UUID> getBookmarkedEventIds(User user) {
        return bookmarkRepository.findEventIdsByUser(user);
    }

    public long countUserBookmarks(User user) {
        return bookmarkRepository.countByUser(user);
    }
}
