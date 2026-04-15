package com.luma.repository;

import com.luma.entity.Event;
import com.luma.entity.Registration;
import com.luma.entity.WaitlistOffer;
import com.luma.entity.enums.WaitlistOfferStatus;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface WaitlistOfferRepository extends JpaRepository<WaitlistOffer, UUID> {

    Optional<WaitlistOffer> findByRegistrationAndStatus(Registration registration, WaitlistOfferStatus status);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT w FROM WaitlistOffer w WHERE w.id = :id")
    Optional<WaitlistOffer> findByIdWithLock(@Param("id") UUID id);

    @Query("SELECT w FROM WaitlistOffer w WHERE w.status = 'PENDING' AND w.expiresAt < :now")
    List<WaitlistOffer> findExpiredOffers(@Param("now") LocalDateTime now);

    @Query("SELECT w FROM WaitlistOffer w WHERE w.event = :event AND w.status = 'PENDING'")
    List<WaitlistOffer> findPendingOffersByEvent(@Param("event") Event event);

    boolean existsByRegistrationAndStatusIn(Registration registration, List<WaitlistOfferStatus> statuses);

    @Query("SELECT w FROM WaitlistOffer w JOIN FETCH w.registration JOIN FETCH w.user JOIN FETCH w.event " +
           "WHERE w.user.id = :userId AND w.status = 'PENDING' ORDER BY w.expiresAt ASC")
    List<WaitlistOffer> findPendingOffersByUser(@Param("userId") UUID userId);

    @Query("SELECT COUNT(w) FROM WaitlistOffer w WHERE w.event = :event AND w.status = 'PENDING'")
    long countPendingOffersByEvent(@Param("event") Event event);

    List<WaitlistOffer> findByEventOrderByCreatedAtDesc(Event event);
}
