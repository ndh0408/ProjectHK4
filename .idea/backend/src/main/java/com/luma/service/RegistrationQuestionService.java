package com.luma.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.luma.dto.request.RegistrationQuestionRequest;
import com.luma.dto.response.RegistrationQuestionResponse;
import com.luma.entity.Event;
import com.luma.entity.RegistrationQuestion;
import com.luma.entity.User;
import com.luma.entity.enums.QuestionType;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.EventRepository;
import com.luma.repository.RegistrationQuestionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class RegistrationQuestionService {

    private final RegistrationQuestionRepository questionRepository;
    private final EventRepository eventRepository;
    private final ObjectMapper objectMapper;

    public List<RegistrationQuestionResponse> getQuestionsByEventId(UUID eventId) {
        List<RegistrationQuestion> questions = questionRepository.findByEventIdOrderByDisplayOrderAsc(eventId);
        return questions.stream()
                .map(RegistrationQuestionResponse::fromEntity)
                .collect(Collectors.toList());
    }

    @Transactional
    public List<RegistrationQuestionResponse> saveQuestions(UUID eventId, List<RegistrationQuestionRequest> requests, User organiser) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));

        if (!event.getOrganiser().getId().equals(organiser.getId())) {
            throw new BadRequestException("You are not the organiser of this event");
        }

        questionRepository.deleteByEventId(eventId);

        for (int i = 0; i < requests.size(); i++) {
            RegistrationQuestionRequest req = requests.get(i);

            if ((req.getQuestionType() == QuestionType.SINGLE_CHOICE ||
                 req.getQuestionType() == QuestionType.MULTIPLE_CHOICE) &&
                (req.getOptions() == null || req.getOptions().isEmpty())) {
                throw new BadRequestException("Options are required for choice questions");
            }

            RegistrationQuestion question = RegistrationQuestion.builder()
                    .event(event)
                    .questionText(req.getQuestionText())
                    .questionType(req.getQuestionType())
                    .options(convertOptionsToJson(req.getOptions()))
                    .required(req.isRequired())
                    .displayOrder(i)
                    .build();

            questionRepository.save(question);
        }

        return getQuestionsByEventId(eventId);
    }

    @Transactional
    public RegistrationQuestionResponse addQuestion(UUID eventId, RegistrationQuestionRequest request, User organiser) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));

        if (!event.getOrganiser().getId().equals(organiser.getId())) {
            throw new BadRequestException("You are not the organiser of this event");
        }

        if ((request.getQuestionType() == QuestionType.SINGLE_CHOICE ||
             request.getQuestionType() == QuestionType.MULTIPLE_CHOICE) &&
            (request.getOptions() == null || request.getOptions().isEmpty())) {
            throw new BadRequestException("Options are required for choice questions");
        }

        int maxOrder = questionRepository.countByEvent(event);

        RegistrationQuestion question = RegistrationQuestion.builder()
                .event(event)
                .questionText(request.getQuestionText())
                .questionType(request.getQuestionType())
                .options(convertOptionsToJson(request.getOptions()))
                .required(request.isRequired())
                .displayOrder(maxOrder)
                .build();

        question = questionRepository.save(question);
        return RegistrationQuestionResponse.fromEntity(question);
    }

    @Transactional
    public RegistrationQuestionResponse updateQuestion(UUID questionId, RegistrationQuestionRequest request, User organiser) {
        RegistrationQuestion question = questionRepository.findById(questionId)
                .orElseThrow(() -> new ResourceNotFoundException("Question not found"));

        if (!question.getEvent().getOrganiser().getId().equals(organiser.getId())) {
            throw new BadRequestException("You are not the organiser of this event");
        }

        if ((request.getQuestionType() == QuestionType.SINGLE_CHOICE ||
             request.getQuestionType() == QuestionType.MULTIPLE_CHOICE) &&
            (request.getOptions() == null || request.getOptions().isEmpty())) {
            throw new BadRequestException("Options are required for choice questions");
        }

        question.setQuestionText(request.getQuestionText());
        question.setQuestionType(request.getQuestionType());
        question.setOptions(convertOptionsToJson(request.getOptions()));
        question.setRequired(request.isRequired());
        question.setDisplayOrder(request.getDisplayOrder());

        question = questionRepository.save(question);
        return RegistrationQuestionResponse.fromEntity(question);
    }

    @Transactional
    public void deleteQuestion(UUID questionId, User organiser) {
        RegistrationQuestion question = questionRepository.findById(questionId)
                .orElseThrow(() -> new ResourceNotFoundException("Question not found"));

        if (!question.getEvent().getOrganiser().getId().equals(organiser.getId())) {
            throw new BadRequestException("You are not the organiser of this event");
        }

        questionRepository.delete(question);
    }

    private String convertOptionsToJson(List<String> options) {
        if (options == null || options.isEmpty()) {
            return null;
        }
        try {
            return objectMapper.writeValueAsString(options);
        } catch (Exception e) {
            return null;
        }
    }
}
