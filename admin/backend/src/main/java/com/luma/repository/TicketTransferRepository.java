package com.luma.repository;

import com.luma.entity.Registration;
import com.luma.entity.TicketTransfer;
import com.luma.entity.User;
import com.luma.entity.enums.TransferStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface TicketTransferRepository extends JpaRepository<TicketTransfer, UUID> {

    Optional<TicketTransfer> findByTransferCode(String transferCode);

    boolean existsByRegistrationAndStatus(Registration registration, TransferStatus status);

    @Query("SELECT t FROM TicketTransfer t WHERE t.toUser = :user AND t.status = 'PENDING' ORDER BY t.createdAt DESC")
    Page<TicketTransfer> findPendingTransfersForUser(@Param("user") User user, Pageable pageable);

    @Query("SELECT t FROM TicketTransfer t WHERE t.fromUser = :user ORDER BY t.createdAt DESC")
    Page<TicketTransfer> findByFromUser(@Param("user") User user, Pageable pageable);

    @Query("SELECT t FROM TicketTransfer t WHERE t.isResale = true AND t.status = 'PENDING' " +
           "AND t.registration.event.id = :eventId ORDER BY t.resalePrice ASC")
    List<TicketTransfer> findResaleListingsByEvent(@Param("eventId") UUID eventId);
}
