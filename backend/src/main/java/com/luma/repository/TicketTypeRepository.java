package com.luma.repository;

import com.luma.entity.Event;
import com.luma.entity.TicketType;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface TicketTypeRepository extends JpaRepository<TicketType, UUID> {

    /**
     * Find ticket type with pessimistic lock to prevent overselling
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT t FROM TicketType t WHERE t.id = :id")
    Optional<TicketType> findByIdWithLock(@Param("id") UUID id);

    List<TicketType> findByEventOrderByDisplayOrderAsc(Event event);

    List<TicketType> findByEventIdOrderByDisplayOrderAsc(UUID eventId);

    // Find only visible ticket types
    List<TicketType> findByEventIdAndIsVisibleTrueOrderByDisplayOrderAsc(UUID eventId);

    // Find available ticket types (visible and have stock)
    @Query("SELECT t FROM TicketType t WHERE t.event.id = :eventId " +
           "AND t.isVisible = true " +
           "AND t.soldCount < t.quantity " +
           "ORDER BY t.displayOrder ASC")
    List<TicketType> findAvailableByEventId(@Param("eventId") UUID eventId);

    // Count ticket types by event
    int countByEvent(Event event);

    int countByEventId(UUID eventId);

    // Find by event and ticket type id (for validation)
    Optional<TicketType> findByIdAndEventId(UUID id, UUID eventId);

    // Check if ticket type belongs to event
    boolean existsByIdAndEventId(UUID id, UUID eventId);

    // Get max display order for event
    @Query("SELECT COALESCE(MAX(t.displayOrder), 0) FROM TicketType t WHERE t.event.id = :eventId")
    int getMaxDisplayOrderByEventId(@Param("eventId") UUID eventId);

    // Update sold count
    @Modifying
    @Query("UPDATE TicketType t SET t.soldCount = t.soldCount + :quantity WHERE t.id = :ticketTypeId AND t.soldCount + :quantity <= t.quantity")
    int incrementSoldCount(@Param("ticketTypeId") UUID ticketTypeId, @Param("quantity") int quantity);

    @Modifying
    @Query("UPDATE TicketType t SET t.soldCount = t.soldCount - :quantity WHERE t.id = :ticketTypeId AND t.soldCount >= :quantity")
    int decrementSoldCount(@Param("ticketTypeId") UUID ticketTypeId, @Param("quantity") int quantity);

    // Delete all ticket types by event
    void deleteByEventId(UUID eventId);

    // Get total available tickets for event
    @Query("SELECT COALESCE(SUM(t.quantity - t.soldCount), 0) FROM TicketType t WHERE t.event.id = :eventId AND t.isVisible = true")
    int getTotalAvailableByEventId(@Param("eventId") UUID eventId);

    // Get total sold tickets for event
    @Query("SELECT COALESCE(SUM(t.soldCount), 0) FROM TicketType t WHERE t.event.id = :eventId")
    int getTotalSoldByEventId(@Param("eventId") UUID eventId);
}
