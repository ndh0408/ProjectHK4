package com.luma.repository;

import com.luma.entity.Event;
import com.luma.entity.RegistrationQuestion;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface RegistrationQuestionRepository extends JpaRepository<RegistrationQuestion, UUID> {

    List<RegistrationQuestion> findByEventOrderByDisplayOrderAsc(Event event);

    List<RegistrationQuestion> findByEventIdOrderByDisplayOrderAsc(UUID eventId);

    int countByEvent(Event event);

    void deleteByEventId(UUID eventId);

    @Query("SELECT q FROM RegistrationQuestion q WHERE q.event.category.id = :categoryId " +
           "AND q.event.id != :excludeEventId ORDER BY q.event.approvedCount DESC")
    List<RegistrationQuestion> findQuestionsFromSimilarEvents(
            @Param("categoryId") Long categoryId,
            @Param("excludeEventId") UUID excludeEventId,
            org.springframework.data.domain.Pageable pageable);
}
