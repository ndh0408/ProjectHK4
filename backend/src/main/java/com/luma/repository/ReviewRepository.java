package com.luma.repository;

import com.luma.entity.Event;
import com.luma.entity.Review;
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
public interface ReviewRepository extends JpaRepository<Review, UUID> {

    // Only show non-flagged reviews to public (or flagged with toxicity < 80)
    @Query("SELECT r FROM Review r WHERE r.event = :event AND (r.flagged = false OR r.toxicityScore < 80) ORDER BY r.createdAt DESC")
    Page<Review> findByEventOrderByCreatedAtDesc(@Param("event") Event event, Pageable pageable);

    Page<Review> findByUserOrderByCreatedAtDesc(User user, Pageable pageable);

    // For organiser to see all reviews including flagged ones
    @Query("SELECT r FROM Review r WHERE r.event = :event ORDER BY r.createdAt DESC")
    Page<Review> findAllByEventOrderByCreatedAtDesc(@Param("event") Event event, Pageable pageable);

    // Get flagged reviews for organiser
    @Query("SELECT r FROM Review r WHERE r.event.organiser = :organiser AND r.flagged = true ORDER BY r.createdAt DESC")
    Page<Review> findFlaggedReviewsByOrganiser(@Param("organiser") User organiser, Pageable pageable);

    // Count flagged reviews for organiser
    @Query("SELECT COUNT(r) FROM Review r WHERE r.event.organiser = :organiser AND r.flagged = true")
    long countFlaggedByOrganiser(@Param("organiser") User organiser);

    Optional<Review> findByEventAndUser(Event event, User user);

    boolean existsByEventAndUser(Event event, User user);

    long countByEvent(Event event);

    @Query("SELECT AVG(r.rating) FROM Review r WHERE r.event.id = :eventId")
    Double getAverageRatingByEventId(@Param("eventId") UUID eventId);

    @Query("SELECT COUNT(r) FROM Review r WHERE r.event.id = :eventId")
    long countByEventId(@Param("eventId") UUID eventId);

    @Query("SELECT AVG(r.rating) FROM Review r WHERE r.event.organiser = :organiser")
    Double getAverageRatingByOrganiser(@Param("organiser") User organiser);

    @Query("SELECT COUNT(r) FROM Review r WHERE r.event.organiser = :organiser")
    long countByOrganiser(@Param("organiser") User organiser);

    @Query("SELECT AVG(r.rating) FROM Review r WHERE r.event.organiser.id = :organiserId")
    Double getAverageRatingForOrganiser(@Param("organiserId") UUID organiserId);

    @Query("SELECT COUNT(r) FROM Review r WHERE r.event.organiser.id = :organiserId")
    long countReviewsForOrganiser(@Param("organiserId") UUID organiserId);
}
