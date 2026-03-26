package com.luma.service;

import com.luma.dto.request.AnswerRequest;
import com.luma.dto.request.QuestionRequest;
import com.luma.dto.response.PageResponse;
import com.luma.dto.response.QuestionResponse;
import com.luma.entity.Event;
import com.luma.entity.Question;
import com.luma.entity.User;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.QuestionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class QuestionService {

    private final QuestionRepository questionRepository;
    private final EventService eventService;
    private final NotificationService notificationService;

    public Question getEntityById(UUID id) {
        return questionRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Question not found"));
    }

    public Question getEntityByIdWithEventAndUser(UUID id) {
        return questionRepository.findByIdWithEventAndUser(id)
                .orElseThrow(() -> new ResourceNotFoundException("Question not found"));
    }

    @Transactional
    public QuestionResponse createQuestion(User user, UUID eventId, QuestionRequest request) {
        Event event = eventService.getEntityById(eventId);

        Question question = Question.builder()
                .user(user)
                .event(event)
                .question(request.getQuestion())
                .build();

        Question savedQuestion = questionRepository.save(question);

        notificationService.notifyOrganiserNewQuestion(savedQuestion);

        return QuestionResponse.fromEntity(savedQuestion);
    }

    @Transactional
    public QuestionResponse answerQuestion(UUID questionId, User organiser, AnswerRequest request) {
        Question question = getEntityById(questionId);

        if (!question.getEvent().getOrganiser().getId().equals(organiser.getId())) {
            throw new BadRequestException("You do not have permission to answer this question");
        }

        question.setAnswer(request.getAnswer());
        question.setAnswered(true);
        question.setAnsweredAt(LocalDateTime.now());

        Question savedQuestion = questionRepository.save(question);

        notificationService.sendQuestionAnsweredNotification(savedQuestion);

        return QuestionResponse.fromEntity(savedQuestion);
    }

    public PageResponse<QuestionResponse> getQuestionsByEvent(UUID eventId, Pageable pageable) {
        Event event = eventService.getEntityById(eventId);
        Page<Question> questions = questionRepository.findByEvent(event, pageable);
        return PageResponse.from(questions, QuestionResponse::fromEntity);
    }

    @Transactional(readOnly = true)
    public PageResponse<QuestionResponse> getQuestionsByOrganiser(User organiser, Pageable pageable) {
        Page<Question> questions = questionRepository.findByOrganiser(organiser, pageable);
        return PageResponse.from(questions, QuestionResponse::fromEntity);
    }

    @Transactional(readOnly = true)
    public PageResponse<QuestionResponse> getUnansweredQuestionsByOrganiser(User organiser, Pageable pageable) {
        Page<Question> questions = questionRepository.findUnansweredByOrganiser(organiser, pageable);
        return PageResponse.from(questions, QuestionResponse::fromEntity);
    }

    @Transactional(readOnly = true)
    public PageResponse<QuestionResponse> getAnsweredQuestionsByOrganiser(User organiser, Pageable pageable) {
        Page<Question> questions = questionRepository.findAnsweredByOrganiser(organiser, pageable);
        return PageResponse.from(questions, QuestionResponse::fromEntity);
    }

    public long countQuestionsByOrganiser(User organiser) {
        return questionRepository.countByOrganiser(organiser);
    }

    public long countUnansweredByOrganiser(User organiser) {
        return questionRepository.countUnansweredByOrganiser(organiser);
    }

    public long countAnsweredByOrganiser(User organiser) {
        return questionRepository.countAnsweredByOrganiser(organiser);
    }

    public PageResponse<QuestionResponse> getUserQuestions(User user, Pageable pageable) {
        Page<Question> questions = questionRepository.findByUser(user, pageable);
        return PageResponse.from(questions, QuestionResponse::fromEntity);
    }

    @Transactional
    public void deleteQuestion(UUID questionId, User organiser) {
        Question question = getEntityById(questionId);

        if (!question.getEvent().getOrganiser().getId().equals(organiser.getId())) {
            throw new BadRequestException("You do not have permission to delete this question");
        }

        questionRepository.delete(question);
    }
}
