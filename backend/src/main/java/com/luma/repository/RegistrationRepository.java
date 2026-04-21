package com.luma.repository;

import com.luma.entity.Event;
import com.luma.entity.Registration;
import com.luma.entity.User;
import com.luma.entity.enums.RegistrationStatus;
import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface RegistrationRepository extends JpaRepository<Registration, UUID> {

    Optional<Registration> findByUserAndEvent(User user, Event event);

    Optional<Registration> findByTicketCode(String ticketCode);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT r FROM Registration r WHERE r.user = :user AND r.event = :event")
    Optional<Registration> findByUserAndEventWithLock(@Param("user") User user, @Param("event") Event event);

    boolean existsByUserAndEvent(User user, Event event);

    boolean existsByEventAndUserAndStatus(Event event, User user, RegistrationStatus status);

    @Query("SELECT CASE WHEN COUNT(r) > 0 THEN true ELSE false END FROM Registration r " +
           "WHERE r.user = :user AND r.event = :event AND r.status NOT IN (:excludedStatuses)")
    boolean existsActiveRegistration(@Param("user") User user, @Param("event") Event event,
                                     @Param("excludedStatuses") List<RegistrationStatus> excludedStatuses);

    @Query("SELECT r FROM Registration r WHERE r.user = :user AND r.event = :event AND r.status NOT IN (:excludedStatuses)")
    Optional<Registration> findActiveByUserAndEvent(@Param("user") User user, @Param("event") Event event,
                                                    @Param("excludedStatuses") List<RegistrationStatus> excludedStatuses);

    Page<Registration> findByUser(User user, Pageable pageable);

    Page<Registration> findByUserOrderByCreatedAtDesc(User user, Pageable pageable);

    Page<Registration> findByEvent(Event event, Pageable pageable);

    Page<Registration> findByEventAndStatus(Event event, RegistrationStatus status, Pageable pageable);

    List<Registration> findByEventAndStatus(Event event, RegistrationStatus status);

    @Query("SELECT r FROM Registration r WHERE r.event = :event AND r.status = 'WAITING_LIST' " +
           "ORDER BY r.waitingListPosition ASC NULLS LAST, r.createdAt ASC")
    List<Registration> findWaitingListByEvent(@Param("event") Event event);

    Optional<Registration> findFirstByEventAndStatusOrderByWaitingListPositionAsc(Event event, RegistrationStatus status);

    long countByEventAndStatus(Event event, RegistrationStatus status);

    @Query("SELECT COALESCE(MAX(r.waitingListPosition), 0) FROM Registration r " +
           "WHERE r.event = :event AND r.status = 'WAITING_LIST'")
    int getMaxWaitingListPosition(@Param("event") Event event);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT COALESCE(MAX(r.waitingListPosition), 0) FROM Registration r " +
           "WHERE r.event = :event AND r.status = 'WAITING_LIST'")
    int getMaxWaitingListPositionWithLock(@Param("event") Event event);

    @Modifying
    @Transactional
    @Query("UPDATE Registration r SET r.waitingListPosition = r.waitingListPosition - 1 " +
           "WHERE r.event = :event AND r.status = 'WAITING_LIST' AND r.waitingListPosition > :position")
    void decrementWaitingListPositionsAfter(@Param("event") Event event, @Param("position") int position);

    @Query("SELECT r FROM Registration r WHERE r.user = :user AND r.status NOT IN ('CANCELLED', 'REJECTED') " +
           "AND r.event.status IN ('PUBLISHED', 'ONGOING') AND r.event.endTime > CURRENT_TIMESTAMP ORDER BY r.event.startTime ASC")
    Page<Registration> findUpcomingRegistrationsByUser(@Param("user") User user, Pageable pageable);

    @Query("SELECT r FROM Registration r WHERE r.user = :user AND r.status NOT IN ('CANCELLED', 'REJECTED') " +
           "AND r.event.status IN ('PUBLISHED', 'ONGOING', 'COMPLETED') AND r.event.endTime < CURRENT_TIMESTAMP ORDER BY r.event.endTime DESC")
    Page<Registration> findPastRegistrationsByUser(@Param("user") User user, Pageable pageable);

    @Query("SELECT COUNT(r) FROM Registration r WHERE r.event.organiser = :organiser AND r.status = 'APPROVED'")
    long countApprovedByOrganiser(@Param("organiser") User organiser);

    @Query("SELECT COUNT(r) FROM Registration r WHERE r.event.organiser = :organiser")
    long countAllByOrganiser(@Param("organiser") User organiser);

    @Query("SELECT COUNT(r) FROM Registration r WHERE r.event.organiser = :organiser AND r.status = :status")
    long countByOrganiserAndStatus(@Param("organiser") User organiser, @Param("status") RegistrationStatus status);

    @Query("SELECT COALESCE(SUM(e.ticketPrice), 0) FROM Registration r JOIN r.event e " +
           "WHERE e.organiser = :organiser AND r.status = 'APPROVED' AND e.ticketPrice > 0")
    BigDecimal calculateTotalRevenueByOrganiser(@Param("organiser") User organiser);

    @Query(value = "SELECT CAST(r.created_at AS DATE) as date, COUNT(*) as count " +
           "FROM registrations r JOIN events e ON r.event_id = e.id " +
           "WHERE e.organiser_id = :organiserId AND r.status = 'APPROVED' " +
           "AND r.created_at >= :startDate GROUP BY CAST(r.created_at AS DATE) ORDER BY date",
           nativeQuery = true)
    List<Object[]> getRegistrationGrowthByOrganiser(@Param("organiserId") UUID organiserId,
                                                     @Param("startDate") LocalDateTime startDate);

    @Query("SELECT COUNT(r) FROM Registration r WHERE MONTH(r.createdAt) = :month AND YEAR(r.createdAt) = :year")
    long countNewRegistrationsInMonth(@Param("month") int month, @Param("year") int year);

    @Query("SELECT COUNT(r) FROM Registration r")
    long countAll();

    @Query("SELECT r FROM Registration r WHERE r.event.startTime BETWEEN :startTime AND :endTime " +
           "AND r.status = :status")
    List<Registration> findByEventStartTimeBetweenAndStatus(
            @Param("startTime") LocalDateTime startTime,
            @Param("endTime") LocalDateTime endTime,
            @Param("status") RegistrationStatus status);

    @Query("SELECT r FROM Registration r WHERE r.status IN :statuses " +
           "AND r.checkedInAt IS NULL " +
           "AND r.event.endTime < :threshold")
    List<Registration> findPotentiallyNoShow(@Param("threshold") LocalDateTime threshold,
                                            @Param("statuses") List<RegistrationStatus> statuses);

    @Query("SELECT r FROM Registration r WHERE r.event IN :events AND r.status IN :statuses")
    List<Registration> findByEventAndStatusIn(@Param("event") Event event, @Param("statuses") List<RegistrationStatus> statuses);

    @Query("SELECT r FROM Registration r WHERE r.event = :event AND r.status = 'APPROVED' AND r.checkedInAt IS NOT NULL")
    List<Registration> findCheckedInByEvent(@Param("event") Event event);

    List<Registration> findByEventAndStatusAndCheckedInAtIsNotNull(Event event, RegistrationStatus status);

    @Query("SELECT COUNT(r) FROM Registration r WHERE r.event = :event AND r.status IN :statuses")
    long countByEventAndStatusIn(@Param("event") Event event, @Param("statuses") List<RegistrationStatus> statuses);

    @Query("SELECT COUNT(r) FROM Registration r WHERE r.event = :event AND r.status IN :statuses AND r.createdAt >= :start")
    long countByEventAndStatusInAndCreatedAtAfter(@Param("event") Event event,
                                                  @Param("statuses") List<RegistrationStatus> statuses,
                                                  @Param("start") LocalDateTime start);

    @Query("SELECT COUNT(r) FROM Registration r WHERE r.event = :event AND r.status IN :statuses AND r.createdAt >= :start AND r.createdAt < :end")
    long countByEventAndStatusInAndCreatedAtRange(@Param("event") Event event,
                                                  @Param("statuses") List<RegistrationStatus> statuses,
                                                  @Param("start") LocalDateTime start,
                                                  @Param("end") LocalDateTime end);

    @Query("SELECT COUNT(r) FROM Registration r WHERE r.event = :event AND r.status = 'APPROVED' AND r.checkedInAt IS NOT NULL")
    long countCheckedInByEvent(@Param("event") Event event);

    @Query("SELECT r FROM Registration r " +
           "JOIN FETCH r.event e " +
           "JOIN FETCH r.user u " +
           "JOIN FETCH e.organiser " +
           "WHERE e.startTime BETWEEN :startTime AND :endTime " +
           "AND r.status = :status AND (r.reminderSent = false OR r.reminderSent IS NULL)")
    List<Registration> findByEventStartTimeBetweenAndStatusAndReminderNotSent(
            @Param("startTime") LocalDateTime startTime,
            @Param("endTime") LocalDateTime endTime,
            @Param("status") RegistrationStatus status);

    @Modifying
    @Transactional
    @Query("UPDATE Registration r SET r.reminderSent = true, r.reminderSentAt = :sentAt WHERE r.id = :id")
    void markReminderSent(@Param("id") UUID id, @Param("sentAt") LocalDateTime sentAt);

    @Query("SELECT r FROM Registration r WHERE r.user.id = :userId AND r.status IN :statuses")
    List<Registration> findByUserIdAndStatusIn(@Param("userId") UUID userId, @Param("statuses") List<RegistrationStatus> statuses);

    long countByCreatedAtAfter(LocalDateTime date);

    long countByCreatedAtBetween(LocalDateTime start, LocalDateTime end);

    @Query("SELECT COUNT(r) FROM Registration r WHERE r.event.organiser.id = :organiserId")
    long countByEventOrganiserId(@Param("organiserId") UUID organiserId);

    @Query("SELECT COUNT(r) FROM Registration r WHERE r.event.organiser.id = :organiserId AND r.createdAt BETWEEN :start AND :end")
    long countByEventOrganiserIdAndCreatedAtBetween(@Param("organiserId") UUID organiserId, @Param("start") LocalDateTime start, @Param("end") LocalDateTime end);

    List<Registration> findByUserAndStatus(User user, RegistrationStatus status);

    List<Registration> findByUserAndStatusIn(User user, List<RegistrationStatus> statuses);

    @Query("SELECT COUNT(r) FROM Registration r WHERE r.user = :user AND r.status = 'APPROVED'")
    long countApprovedByUser(@Param("user") User user);

    @Query("SELECT COUNT(r) FROM Registration r WHERE r.user = :user AND r.status = :status")
    long countByUserAndStatus(@Param("user") User user, @Param("status") RegistrationStatus status);

    @Query("SELECT COUNT(r) FROM Registration r WHERE r.status = :status")
    long countByStatusGlobal(@Param("status") RegistrationStatus status);

    @Query("SELECT COUNT(r) FROM Registration r WHERE r.status = 'APPROVED' AND r.checkedInAt IS NOT NULL")
    long countCheckedInGlobal();

    @Query("SELECT COUNT(r) FROM Registration r WHERE r.event.organiser.id = :organiserId AND r.status = 'APPROVED'")
    long countApprovedByOrganiserId(@Param("organiserId") UUID organiserId);

    @Query("SELECT COUNT(r) FROM Registration r WHERE r.event.organiser.id = :organiserId AND r.status = 'APPROVED' AND r.checkedInAt IS NOT NULL")
    long countCheckedInByOrganiserId(@Param("organiserId") UUID organiserId);

    @Query("SELECT r FROM Registration r JOIN FETCH r.user JOIN FETCH r.event " +
           "WHERE r.event IN :events AND r.status IN :statuses")
    List<Registration> findByEventInAndStatusIn(@Param("events") List<Event> events,
                                                 @Param("statuses") List<RegistrationStatus> statuses);
}
