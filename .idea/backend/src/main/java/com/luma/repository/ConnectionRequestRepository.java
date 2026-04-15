package com.luma.repository;

import com.luma.entity.ConnectionRequest;
import com.luma.entity.User;
import com.luma.entity.enums.ConnectionStatus;
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
public interface ConnectionRequestRepository extends JpaRepository<ConnectionRequest, UUID> {

    Optional<ConnectionRequest> findBySenderAndReceiver(User sender, User receiver);

    @Query("SELECT cr FROM ConnectionRequest cr WHERE cr.receiver = :user AND cr.status = 'PENDING' ORDER BY cr.createdAt DESC")
    Page<ConnectionRequest> findPendingRequestsForUser(@Param("user") User user, Pageable pageable);

    @Query("SELECT cr FROM ConnectionRequest cr WHERE " +
           "(cr.sender = :user OR cr.receiver = :user) AND cr.status = 'ACCEPTED' ORDER BY cr.respondedAt DESC")
    Page<ConnectionRequest> findAcceptedConnections(@Param("user") User user, Pageable pageable);

    @Query("SELECT cr FROM ConnectionRequest cr WHERE cr.sender = :user ORDER BY cr.createdAt DESC")
    Page<ConnectionRequest> findSentRequests(@Param("user") User user, Pageable pageable);

    @Query("SELECT CASE WHEN COUNT(cr) > 0 THEN true ELSE false END FROM ConnectionRequest cr " +
           "WHERE ((cr.sender = :user1 AND cr.receiver = :user2) OR (cr.sender = :user2 AND cr.receiver = :user1)) " +
           "AND cr.status = 'ACCEPTED'")
    boolean areConnected(@Param("user1") User user1, @Param("user2") User user2);

    @Query("SELECT CASE WHEN COUNT(cr) > 0 THEN true ELSE false END FROM ConnectionRequest cr " +
           "WHERE cr.sender = :sender AND cr.receiver = :receiver AND cr.status IN :statuses")
    boolean existsBySenderAndReceiverAndStatusIn(@Param("sender") User sender, @Param("receiver") User receiver,
                                                   @Param("statuses") List<ConnectionStatus> statuses);

    @Query("SELECT COUNT(cr) FROM ConnectionRequest cr WHERE " +
           "(cr.sender = :user OR cr.receiver = :user) AND cr.status = 'ACCEPTED'")
    long countConnections(@Param("user") User user);

    @Query("SELECT COUNT(cr) FROM ConnectionRequest cr WHERE cr.receiver = :user AND cr.status = 'PENDING'")
    long countPendingRequests(@Param("user") User user);
}
