package com.luma.repository;

import com.luma.entity.OrganiserVerificationRequest;
import com.luma.entity.User;
import com.luma.entity.enums.VerificationStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface OrganiserVerificationRequestRepository extends JpaRepository<OrganiserVerificationRequest, UUID> {

    Optional<OrganiserVerificationRequest> findTopByOrganiserOrderBySubmittedAtDesc(User organiser);

    boolean existsByOrganiserAndStatus(User organiser, VerificationStatus status);

    Page<OrganiserVerificationRequest> findByStatusOrderBySubmittedAtAsc(VerificationStatus status, Pageable pageable);

    Page<OrganiserVerificationRequest> findByStatusAndIsApplicationOrderBySubmittedAtAsc(
            VerificationStatus status, boolean isApplication, Pageable pageable);

    Page<OrganiserVerificationRequest> findByIsApplicationOrderBySubmittedAtDesc(
            boolean isApplication, Pageable pageable);

    Page<OrganiserVerificationRequest> findAllByOrderBySubmittedAtDesc(Pageable pageable);

    long countByStatus(VerificationStatus status);

    long countByStatusAndIsApplication(VerificationStatus status, boolean isApplication);
}
