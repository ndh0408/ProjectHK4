package com.luma.repository;

import com.luma.entity.Event;
import com.luma.entity.Question;
import com.luma.entity.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface QuestionRepository extends JpaRepository<Question, UUID> {

    @Query("SELECT q FROM Question q LEFT JOIN FETCH q.event e LEFT JOIN FETCH e.organiser LEFT JOIN FETCH q.user WHERE q.id = :id")
    Optional<Question> findByIdWithEventAndUser(@Param("id") UUID id);

    Page<Question> findByEvent(Event event, Pageable pageable);

    Page<Question> findByUser(User user, Pageable pageable);

    Page<Question> findByEventAndIsAnswered(Event event, boolean isAnswered, Pageable pageable);

    @Query(value = "SELECT q FROM Question q JOIN FETCH q.event e JOIN FETCH q.user WHERE e.organiser = :organiser",
           countQuery = "SELECT COUNT(q) FROM Question q WHERE q.event.organiser = :organiser")
    Page<Question> findByOrganiser(@Param("organiser") User organiser, Pageable pageable);

    @Query(value = "SELECT q FROM Question q JOIN FETCH q.event e JOIN FETCH q.user WHERE e.organiser = :organiser AND q.isAnswered = false",
           countQuery = "SELECT COUNT(q) FROM Question q WHERE q.event.organiser = :organiser AND q.isAnswered = false")
    Page<Question> findUnansweredByOrganiser(@Param("organiser") User organiser, Pageable pageable);

    @Query(value = "SELECT q FROM Question q JOIN FETCH q.event e JOIN FETCH q.user WHERE e.organiser = :organiser AND q.isAnswered = true",
           countQuery = "SELECT COUNT(q) FROM Question q WHERE q.event.organiser = :organiser AND q.isAnswered = true")
    Page<Question> findAnsweredByOrganiser(@Param("organiser") User organiser, Pageable pageable);

    long countByEventAndIsAnswered(Event event, boolean isAnswered);

    @Query("SELECT COUNT(q) FROM Question q WHERE q.event.organiser = :organiser")
    long countByOrganiser(@Param("organiser") User organiser);

    @Query("SELECT COUNT(q) FROM Question q WHERE q.event.organiser = :organiser AND q.isAnswered = false")
    long countUnansweredByOrganiser(@Param("organiser") User organiser);

    @Query("SELECT COUNT(q) FROM Question q WHERE q.event.organiser = :organiser AND q.isAnswered = true")
    long countAnsweredByOrganiser(@Param("organiser") User organiser);

    @Query(value = "SELECT q FROM Question q JOIN FETCH q.event e " +
           "WHERE q.isAnswered = true AND e.category = :category " +
           "ORDER BY q.answeredAt DESC")
    Page<Question> findAnsweredByCategory(@Param("category") com.luma.entity.Category category, Pageable pageable);

    @Query("SELECT q FROM Question q WHERE q.event = :event AND q.isAnswered = true ORDER BY q.answeredAt DESC")
    java.util.List<Question> findAnsweredByEvent(@Param("event") Event event);

    @Query(value = "SELECT q FROM Question q JOIN FETCH q.event e " +
           "WHERE e.organiser = :organiser AND q.isAnswered = true " +
           "ORDER BY q.answeredAt DESC")
    Page<Question> findAnsweredHistoryByOrganiser(@Param("organiser") User organiser, Pageable pageable);

    @Query(value = "SELECT q FROM Question q WHERE q.isAnswered = true " +
           "AND (LOWER(q.question) LIKE LOWER(CONCAT('%', :keyword, '%')))")
    java.util.List<Question> findSimilarAnsweredQuestions(@Param("keyword") String keyword, Pageable pageable);
}
