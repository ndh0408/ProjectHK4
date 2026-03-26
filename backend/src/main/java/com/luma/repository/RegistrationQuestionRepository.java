package com.luma.repository;

import com.luma.entity.Event;
import com.luma.entity.RegistrationQuestion;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface RegistrationQuestionRepository extends JpaRepository<RegistrationQuestion, UUID> {

    List<RegistrationQuestion> findByEventOrderByDisplayOrderAsc(Event event);

    List<RegistrationQuestion> findByEventIdOrderByDisplayOrderAsc(UUID eventId);

    int countByEvent(Event event);

    void deleteByEventId(UUID eventId);
}
