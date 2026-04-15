package com.luma.repository;

import com.luma.entity.Registration;
import com.luma.entity.RegistrationAnswer;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface RegistrationAnswerRepository extends JpaRepository<RegistrationAnswer, UUID> {

    List<RegistrationAnswer> findByRegistration(Registration registration);

    List<RegistrationAnswer> findByRegistrationId(UUID registrationId);
}
