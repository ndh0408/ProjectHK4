package com.luma.repository;

import com.luma.entity.Certificate;
import com.luma.entity.Registration;
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
public interface CertificateRepository extends JpaRepository<Certificate, UUID> {

    Optional<Certificate> findByRegistration(Registration registration);

    Optional<Certificate> findByCertificateCode(String certificateCode);

    boolean existsByRegistration(Registration registration);

    @Query("SELECT c FROM Certificate c WHERE c.registration.user = :user ORDER BY c.generatedAt DESC")
    Page<Certificate> findByUser(@Param("user") User user, Pageable pageable);

    @Query("SELECT c FROM Certificate c WHERE c.registration.event.organiser = :organiser ORDER BY c.generatedAt DESC")
    Page<Certificate> findByOrganiser(@Param("organiser") User organiser, Pageable pageable);

    @Query("SELECT c FROM Certificate c WHERE c.registration.event.id = :eventId ORDER BY c.generatedAt DESC")
    Page<Certificate> findByEventId(@Param("eventId") UUID eventId, Pageable pageable);

    Optional<Certificate> findByRegistrationId(UUID registrationId);
}
