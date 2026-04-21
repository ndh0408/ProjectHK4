package com.luma.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.luma.entity.Event;
import com.luma.entity.Registration;
import com.luma.entity.SupportRequest;
import com.luma.entity.User;
import com.luma.repository.SupportRequestRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;

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
}
