package com.luma.repository;

import com.luma.entity.SupportRequest;
import com.luma.entity.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface SupportRequestRepository extends JpaRepository<SupportRequest, UUID> {

    List<SupportRequest> findByUserOrderByCreatedAtDesc(User user);

    Page<SupportRequest> findByStatusOrderByCreatedAtAsc(SupportRequest.Status status, Pageable pageable);

    long countByStatus(SupportRequest.Status status);
}
