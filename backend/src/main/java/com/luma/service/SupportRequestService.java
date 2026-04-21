package com.luma.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.luma.dto.response.PageResponse;
import com.luma.dto.response.SupportRequestResponse;
import com.luma.entity.Event;
import com.luma.entity.Registration;
import com.luma.entity.SupportRequest;
import com.luma.entity.User;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.SupportRequestRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
@Slf4j
@RequiredArgsConstructor
public class SupportRequestService {

    private final SupportRequestRepository repository;
    private final ObjectMapper objectMapper;

    @Transactional
    public SupportRequest escalateFromChat(
            User user,
            String subject,
            String message,
            SupportRequest.Category category,
            List<Map<String, String>> transcript,
            Event relatedEvent,
            Registration relatedRegistration
    ) {
        String transcriptJson;
        try {
            transcriptJson = transcript == null ? null : objectMapper.writeValueAsString(transcript);
        } catch (JsonProcessingException e) {
            log.warn("Failed to serialize chat transcript for support request: {}", e.getMessage());
            transcriptJson = null;
        }

        SupportRequest request = SupportRequest.builder()
                .user(user)
                .subject(subject == null || subject.isBlank()
                        ? "Chatbot escalation"
                        : subject.substring(0, Math.min(subject.length(), 200)))
                .message(message == null ? "" : message.substring(0, Math.min(message.length(), 2000)))
                .category(category != null ? category : SupportRequest.Category.OTHER)
                .status(SupportRequest.Status.OPEN)
                .transcript(transcriptJson)
                .relatedEvent(relatedEvent)
                .relatedRegistration(relatedRegistration)
                .build();

        request = repository.save(request);
        log.info("Support request created from chat: id={} user={} category={}",
                request.getId(),
                user != null ? user.getId() : "anonymous",
                request.getCategory());
        return request;
    }

    // ───────────────────────────── Admin ─────────────────────────────

    @Transactional(readOnly = true)
    public PageResponse<SupportRequestResponse> listForAdmin(String statusFilter, int page, int size) {
        Sort sort = Sort.by(Sort.Direction.DESC, "createdAt");
        PageRequest pageable = PageRequest.of(page, size, sort);

        Page<SupportRequest> pageResult;
        if (statusFilter == null || statusFilter.isBlank() || "ALL".equalsIgnoreCase(statusFilter)) {
            pageResult = repository.findAll(pageable);
        } else {
            SupportRequest.Status status;
            try {
                status = SupportRequest.Status.valueOf(statusFilter.toUpperCase());
            } catch (IllegalArgumentException e) {
                pageResult = repository.findAll(pageable);
                return PageResponse.from(pageResult, r -> SupportRequestResponse.fromEntity(r, objectMapper));
            }
            // Use the existing "by status, oldest first" so newest OPEN surfaces
            // last — admins usually want to triage oldest first.
            pageResult = repository.findByStatusOrderByCreatedAtAsc(status, pageable);
        }
        return PageResponse.from(pageResult, r -> SupportRequestResponse.fromEntity(r, objectMapper));
    }

    @Transactional(readOnly = true)
    public SupportRequestResponse getForAdmin(UUID id) {
        SupportRequest r = repository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Support request not found"));
        return SupportRequestResponse.fromEntity(r, objectMapper);
    }

    @Transactional
    public SupportRequestResponse updateStatus(UUID id, SupportRequest.Status newStatus,
                                               String resolutionNote, User resolvedBy) {
        SupportRequest r = repository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Support request not found"));
        r.setStatus(newStatus);
        if (resolutionNote != null) {
            r.setResolutionNote(resolutionNote.length() > 500
                    ? resolutionNote.substring(0, 500) : resolutionNote);
        }
        if (newStatus == SupportRequest.Status.RESOLVED || newStatus == SupportRequest.Status.CLOSED) {
            r.setResolvedBy(resolvedBy);
            r.setResolvedAt(LocalDateTime.now());
        }
        return SupportRequestResponse.fromEntity(repository.save(r), objectMapper);
    }

    @Transactional(readOnly = true)
    public Map<String, Long> getAdminCounts() {
        return Map.of(
                "open", repository.countByStatus(SupportRequest.Status.OPEN),
                "inProgress", repository.countByStatus(SupportRequest.Status.IN_PROGRESS),
                "resolved", repository.countByStatus(SupportRequest.Status.RESOLVED),
                "closed", repository.countByStatus(SupportRequest.Status.CLOSED)
        );
    }
}
