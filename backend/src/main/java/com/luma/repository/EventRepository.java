package com.luma.repository;

import com.luma.entity.Category;
import com.luma.entity.City;
import com.luma.entity.Event;
import com.luma.entity.User;
import com.luma.entity.enums.EventStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Repository
public interface EventRepository extends JpaRepository<Event, UUID> {

    Page<Event> findByOrganiser(User organiser, Pageable pageable);

    Page<Event> findByOrganiserAndStatus(User organiser, EventStatus status, Pageable pageable);

    Page<Event> findByStatus(EventStatus status, Pageable pageable);

    Page<Event> findByTitleContainingIgnoreCase(String title, Pageable pageable);

    Page<Event> findByTitleContainingIgnoreCaseAndStatus(String title, EventStatus status, Pageable pageable);

    Page<Event> findByCategory(Category category, Pageable pageable);

    Page<Event> findByCity(City city, Pageable pageable);

    @Query("SELECT e FROM Event e WHERE e.status = 'PUBLISHED' AND e.visibility = 'PUBLIC' " +
           "AND e.startTime BETWEEN :now AND :endDate ORDER BY e.startTime ASC")
    Page<Event> findUpcomingPublicEvents(
            @Param("now") LocalDateTime now,
            @Param("endDate") LocalDateTime endDate,
            Pageable pageable);

    @Query("SELECT e FROM Event e WHERE e.city = :city AND e.status = 'PUBLISHED' " +
           "AND e.visibility = 'PUBLIC' AND e.startTime BETWEEN :now AND :endDate " +
           "ORDER BY e.startTime ASC")
    Page<Event> findUpcomingEventsByCity(
            @Param("city") City city,
            @Param("now") LocalDateTime now,
            @Param("endDate") LocalDateTime endDate,
            Pageable pageable);

    @Query("SELECT e FROM Event e WHERE e.category = :category AND e.status = 'PUBLISHED' " +
           "AND e.visibility = 'PUBLIC' AND e.startTime > :now ORDER BY e.startTime ASC")
    Page<Event> findUpcomingEventsByCategory(
            @Param("category") Category category,
            @Param("now") LocalDateTime now,
            Pageable pageable);

    @Query("SELECT e FROM Event e WHERE e.status = 'PUBLISHED' AND e.visibility = 'PUBLIC' AND " +
           "(LOWER(e.title) LIKE LOWER(CONCAT('%', :query, '%')) OR " +
           "LOWER(e.description) LIKE LOWER(CONCAT('%', :query, '%')))")
    Page<Event> searchEvents(@Param("query") String query, Pageable pageable);

    @Query("SELECT e FROM Event e " +
           "LEFT JOIN EventBoost b ON e.id = b.event.id AND b.status = 'ACTIVE' AND b.startTime <= :now AND b.endTime > :now " +
           "WHERE e.status = 'PUBLISHED' AND e.visibility = 'PUBLIC' AND " +
           "(LOWER(e.title) LIKE LOWER(CONCAT('%', :query, '%')) OR " +
           "LOWER(e.description) LIKE LOWER(CONCAT('%', :query, '%'))) " +
           "ORDER BY CASE WHEN b.boostPackage IS NOT NULL THEN 0 ELSE 1 END, " +
           "CASE b.boostPackage WHEN 'VIP' THEN 0 WHEN 'PREMIUM' THEN 1 WHEN 'STANDARD' THEN 2 WHEN 'BASIC' THEN 3 ELSE 4 END, " +
           "e.startTime ASC")
    Page<Event> searchEventsWithBoostPriority(@Param("query") String query, @Param("now") LocalDateTime now, Pageable pageable);

    @Query("SELECT e FROM Event e " +
           "LEFT JOIN EventBoost b ON e.id = b.event.id AND b.status = 'ACTIVE' AND b.startTime <= :now AND b.endTime > :now " +
           "WHERE e.status = 'PUBLISHED' AND e.visibility = 'PUBLIC' " +
           "AND e.startTime BETWEEN :now AND :endDate " +
           "ORDER BY CASE WHEN b.boostPackage IS NOT NULL THEN 0 ELSE 1 END, " +
           "CASE b.boostPackage WHEN 'VIP' THEN 0 WHEN 'PREMIUM' THEN 1 WHEN 'STANDARD' THEN 2 WHEN 'BASIC' THEN 3 ELSE 4 END, " +
           "e.startTime ASC")
    Page<Event> findUpcomingEventsWithBoostPriority(
            @Param("now") LocalDateTime now,
            @Param("endDate") LocalDateTime endDate,
            Pageable pageable);

    @Query("SELECT e FROM Event e " +
           "LEFT JOIN EventBoost b ON e.id = b.event.id AND b.status = 'ACTIVE' AND b.startTime <= :now AND b.endTime > :now " +
           "WHERE e.category = :category AND e.status = 'PUBLISHED' " +
           "AND e.visibility = 'PUBLIC' AND e.startTime > :now " +
           "ORDER BY CASE WHEN b.boostPackage IS NOT NULL THEN 0 ELSE 1 END, " +
           "CASE b.boostPackage WHEN 'VIP' THEN 0 WHEN 'PREMIUM' THEN 1 WHEN 'STANDARD' THEN 2 WHEN 'BASIC' THEN 3 ELSE 4 END, " +
           "e.startTime ASC")
    Page<Event> findEventsByCategoryWithBoostPriority(
            @Param("category") Category category,
            @Param("now") LocalDateTime now,
            Pageable pageable);

    @Query("SELECT e FROM Event e " +
           "LEFT JOIN EventBoost b ON e.id = b.event.id AND b.status = 'ACTIVE' AND b.startTime <= :now AND b.endTime > :now " +
           "WHERE e.city = :city AND e.status = 'PUBLISHED' " +
           "AND e.visibility = 'PUBLIC' AND e.startTime BETWEEN :now AND :endDate " +
           "ORDER BY CASE WHEN b.boostPackage IS NOT NULL THEN 0 ELSE 1 END, " +
           "CASE b.boostPackage WHEN 'VIP' THEN 0 WHEN 'PREMIUM' THEN 1 WHEN 'STANDARD' THEN 2 WHEN 'BASIC' THEN 3 ELSE 4 END, " +
           "e.startTime ASC")
    Page<Event> findEventsByCityWithBoostPriority(
            @Param("city") City city,
            @Param("now") LocalDateTime now,
            @Param("endDate") LocalDateTime endDate,
            Pageable pageable);

    @Query("SELECT e FROM Event e WHERE e.organiser.id = :organiserId AND e.status = 'PUBLISHED' " +
           "AND e.startTime BETWEEN :now AND :endDate ORDER BY e.startTime ASC")
    Page<Event> findUpcomingEventsByOrganiser(
            @Param("organiserId") UUID organiserId,
            @Param("now") LocalDateTime now,
            @Param("endDate") LocalDateTime endDate,
            Pageable pageable);

    @Query("SELECT e FROM Event e WHERE e.organiser.id = :organiserId AND e.status = 'COMPLETED' " +
           "ORDER BY e.endTime DESC")
    Page<Event> findPastEventsByOrganiser(
            @Param("organiserId") UUID organiserId,
            Pageable pageable);

    @Query("SELECT COUNT(e) FROM Event e WHERE e.organiser = :organiser")
    long countByOrganiser(@Param("organiser") User organiser);

    long countByStatus(EventStatus status);

    @Query("SELECT COUNT(e) FROM Event e WHERE e.organiser = :organiser AND e.status = :status")
    long countByOrganiserAndStatus(@Param("organiser") User organiser, @Param("status") EventStatus status);

    @Query("SELECT e.city.id, e.city.name, COUNT(e) FROM Event e WHERE e.status = 'PUBLISHED' " +
           "GROUP BY e.city.id, e.city.name ORDER BY COUNT(e) DESC")
    List<Object[]> countEventsByCity();

    @Query("SELECT e.category.id, e.category.name, COUNT(e) FROM Event e WHERE e.status = 'PUBLISHED' " +
           "GROUP BY e.category.id, e.category.name ORDER BY COUNT(e) DESC")
    List<Object[]> countEventsByCategory();

    @Query("SELECT YEAR(e.createdAt), MONTH(e.createdAt), COUNT(e) FROM Event e " +
           "WHERE e.createdAt >= :startDate GROUP BY YEAR(e.createdAt), MONTH(e.createdAt) " +
           "ORDER BY YEAR(e.createdAt), MONTH(e.createdAt)")
    List<Object[]> countNewEventsPerMonth(@Param("startDate") LocalDateTime startDate);

    long countByCity(City city);

    @Query("SELECT e FROM Event e " +
           "LEFT JOIN FETCH e.organiser " +
           "LEFT JOIN FETCH e.category " +
           "LEFT JOIN FETCH e.city " +
           "WHERE e.id = :eventId")
    java.util.Optional<Event> findByIdWithBasicRelationships(@Param("eventId") UUID eventId);

    @Query("SELECT DISTINCT e FROM Event e " +
           "LEFT JOIN FETCH e.speakers " +
           "WHERE e.id = :eventId")
    java.util.Optional<Event> findByIdWithSpeakers(@Param("eventId") UUID eventId);

    @Query("SELECT DISTINCT e FROM Event e " +
           "LEFT JOIN FETCH e.registrationQuestions " +
           "WHERE e.id = :eventId")
    java.util.Optional<Event> findByIdWithRegistrationQuestions(@Param("eventId") UUID eventId);

    @Query("SELECT e FROM Event e " +
           "LEFT JOIN FETCH e.organiser " +
           "LEFT JOIN FETCH e.category " +
           "LEFT JOIN FETCH e.city " +
           "LEFT JOIN FETCH e.speakers " +
           "WHERE e.id = :eventId")
    java.util.Optional<Event> findByIdWithRelationships(@Param("eventId") UUID eventId);

    @Query("SELECT e FROM Event e " +
           "LEFT JOIN EventBoost b ON e.id = b.event.id AND b.status = 'ACTIVE' AND b.startTime <= :now AND b.endTime > :now " +
           "WHERE e.status = 'PUBLISHED' AND e.visibility = 'PUBLIC' " +
           "ORDER BY CASE WHEN b.boostPackage IS NOT NULL THEN 0 ELSE 1 END, " +
           "CASE b.boostPackage WHEN 'VIP' THEN 0 WHEN 'PREMIUM' THEN 1 WHEN 'STANDARD' THEN 2 WHEN 'BASIC' THEN 3 ELSE 4 END, " +
           "e.startTime ASC")
    Page<Event> findFeaturedPublicEvents(@Param("now") LocalDateTime now, Pageable pageable);

    @Query("SELECT DISTINCT e FROM Event e JOIN e.speakers s WHERE LOWER(s.name) = LOWER(:speakerName) " +
           "AND e.status = 'PUBLISHED' AND e.visibility = 'PUBLIC' ORDER BY e.startTime DESC")
    Page<Event> findEventsBySpeakerName(@Param("speakerName") String speakerName, Pageable pageable);

    @Query("SELECT e FROM Event e " +
           "LEFT JOIN EventBoost b ON e.id = b.event.id AND b.status = 'ACTIVE' AND b.startTime <= :now AND b.endTime > :now " +
           "WHERE e.city.country = :country AND e.status = 'PUBLISHED' " +
           "AND e.visibility = 'PUBLIC' AND e.startTime BETWEEN :now AND :endDate " +
           "ORDER BY CASE WHEN b.boostPackage IS NOT NULL THEN 0 ELSE 1 END, " +
           "CASE b.boostPackage WHEN 'VIP' THEN 0 WHEN 'PREMIUM' THEN 1 WHEN 'STANDARD' THEN 2 WHEN 'BASIC' THEN 3 ELSE 4 END, " +
           "e.startTime ASC")
    Page<Event> findUpcomingEventsByCountryWithBoostPriority(
            @Param("country") String country,
            @Param("now") LocalDateTime now,
            @Param("endDate") LocalDateTime endDate,
            Pageable pageable);

    Page<Event> findByOrganiserOrderByCreatedAtDesc(User organiser, Pageable pageable);

    long countByCreatedAtAfter(LocalDateTime date);

    @Query("SELECT COUNT(e) FROM Event e WHERE e.status = 'PUBLISHED' " +
           "AND e.capacity > 0 AND (SELECT COUNT(r) FROM Registration r WHERE r.event = e AND r.status = 'APPROVED') < (e.capacity * 0.2)")
    long countLowRegistrationEvents();

    @Query("SELECT COUNT(r) FROM Registration r WHERE r.event.id = :eventId " +
           "AND r.status IN ('APPROVED', 'PENDING', 'WAITING_LIST')")
    long countActiveRegistrations(@Param("eventId") UUID eventId);

    List<Event> findByStatusAndStartTimeBefore(EventStatus status, LocalDateTime dateTime);

    List<Event> findByStatusAndEndTimeBefore(EventStatus status, LocalDateTime dateTime);

    List<Event> findByStatusAndEndTimeBetween(EventStatus status, LocalDateTime start, LocalDateTime end);

    long countByCreatedAtBetween(LocalDateTime start, LocalDateTime end);

    long countByOrganiserId(UUID organiserId);

    long countByOrganiserIdAndStatus(UUID organiserId, EventStatus status);

    @Query("SELECT COUNT(e) FROM Event e WHERE e.organiser.id = :organiserId AND e.status = 'COMPLETED'")
    long countCompletedEventsByOrganiser(@Param("organiserId") UUID organiserId);

    @Query("SELECT c.id, c.name, COUNT(e) FROM Event e JOIN e.category c GROUP BY c.id, c.name ORDER BY COUNT(e) DESC")
    List<Object[]> countEventsByCategoryAll();

    @Query("SELECT ci.id, ci.name, ci.country, COUNT(e) FROM Event e JOIN e.city ci GROUP BY ci.id, ci.name, ci.country ORDER BY COUNT(e) DESC")
    List<Object[]> countEventsByCityAll();

    @Query("SELECT e.organiser.id, e.organiser.fullName, e.organiser.email, e.organiser.avatarUrl, " +
           "COUNT(DISTINCT e), COUNT(r), COALESCE(SUM(p.amount), 0) " +
           "FROM Event e LEFT JOIN e.registrations r LEFT JOIN Payment p ON p.registration = r " +
           "WHERE r.status = 'APPROVED' OR r.status IS NULL " +
           "GROUP BY e.organiser.id, e.organiser.fullName, e.organiser.email, e.organiser.avatarUrl " +
           "ORDER BY COUNT(r) DESC")
    List<Object[]> findTopOrganisersByRegistrations(int limit);

    @Query(value = "SELECT TOP(:limit) e.id, e.title, u.full_name, e.image_url, " +
           "COUNT(r.id) as reg_count, COALESCE(SUM(p.amount), 0) as revenue, e.capacity " +
           "FROM events e " +
           "JOIN users u ON e.organiser_id = u.id " +
           "LEFT JOIN registrations r ON r.event_id = e.id AND r.status = 'APPROVED' " +
           "LEFT JOIN payments p ON p.registration_id = r.id AND p.status = 'SUCCEEDED' " +
           "WHERE e.status = 'PUBLISHED' " +
           "GROUP BY e.id, e.title, u.full_name, e.image_url, e.capacity " +
           "ORDER BY reg_count DESC", nativeQuery = true)
    List<Object[]> findTopEventsByRegistrations(@Param("limit") int limit);

    @Query("SELECT e FROM Event e LEFT JOIN FETCH e.organiser WHERE e.imageUrl IS NOT NULL")
    Page<Event> findByImageUrlIsNotNull(Pageable pageable);

    @Query("SELECT e FROM Event e LEFT JOIN FETCH e.organiser WHERE e.category.id = :categoryId AND e.imageUrl IS NOT NULL")
    Page<Event> findByCategoryIdAndImageUrlIsNotNull(@Param("categoryId") Long categoryId, Pageable pageable);

    @Query("SELECT e FROM Event e WHERE e.organiser.id = :organiserId ORDER BY e.startTime DESC")
    List<Event> findByOrganiserIdOrderByStartTimeDesc(@Param("organiserId") UUID organiserId);

    @Query("SELECT e FROM Event e WHERE e.category.id = :categoryId AND e.status = 'PUBLISHED' " +
           "AND e.description IS NOT NULL AND LENGTH(e.description) > 200 " +
           "ORDER BY e.approvedCount DESC")
    List<Event> findTopEventsByCategory(@Param("categoryId") Long categoryId, Pageable pageable);

    @Query("SELECT e FROM Event e WHERE e.category.id = :categoryId AND e.status = 'PUBLISHED' " +
           "AND e.capacity > 0 AND e.approvedCount > 0 ORDER BY (CAST(e.approvedCount AS double) / e.capacity) DESC")
    List<Event> findHighFillRateEventsByCategory(@Param("categoryId") Long categoryId, Pageable pageable);

    @Query("SELECT e FROM Event e WHERE e.category.id = :categoryId AND e.status IN ('PUBLISHED', 'COMPLETED') " +
           "AND e.ticketPrice IS NOT NULL AND e.ticketPrice > 0")
    List<Event> findPaidEventsByCategory(@Param("categoryId") Long categoryId, Pageable pageable);

    @Query("SELECT e FROM Event e WHERE e.status = 'REJECTED' AND e.rejectionReason IS NOT NULL " +
           "ORDER BY e.updatedAt DESC")
    List<Event> findRecentRejectedEvents(Pageable pageable);

    @Query("SELECT e FROM Event e WHERE e.status = 'PUBLISHED' AND e.organiser.id = :organiserId " +
           "ORDER BY e.approvedCount DESC")
    List<Event> findTopEventsByOrganiser(@Param("organiserId") UUID organiserId, Pageable pageable);

    @Query("SELECT e FROM Event e WHERE e.status = 'PUBLISHED' AND e.visibility = 'PUBLIC' " +
           "AND (LOWER(e.title) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
           "OR LOWER(e.description) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
           "OR LOWER(e.venue) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
           "OR LOWER(e.address) LIKE LOWER(CONCAT('%', :keyword, '%'))) " +
           "AND e.startTime > :now")
    List<Event> searchEventsByKeyword(@Param("keyword") String keyword,
                                       @Param("now") LocalDateTime now,
                                       Pageable pageable);
}
