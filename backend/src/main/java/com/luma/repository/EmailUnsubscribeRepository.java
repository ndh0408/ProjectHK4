package com.luma.repository;

import com.luma.entity.EmailUnsubscribe;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface EmailUnsubscribeRepository extends JpaRepository<EmailUnsubscribe, UUID> {

    boolean existsByEmail(String email);

    Optional<EmailUnsubscribe> findByEmail(String email);

    void deleteByEmail(String email);

    long count();
}
