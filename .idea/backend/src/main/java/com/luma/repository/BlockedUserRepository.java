package com.luma.repository;

import com.luma.entity.BlockedUser;
import com.luma.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

@Repository
public interface BlockedUserRepository extends JpaRepository<BlockedUser, UUID> {

    Optional<BlockedUser> findByBlockerAndBlocked(User blocker, User blocked);

    boolean existsByBlockerAndBlocked(User blocker, User blocked);

    @Query("SELECT b FROM BlockedUser b WHERE b.blocker = :user ORDER BY b.blockedAt DESC")
    List<BlockedUser> findByBlocker(@Param("user") User user);

    @Query("SELECT CASE WHEN COUNT(b) > 0 THEN true ELSE false END FROM BlockedUser b " +
           "WHERE (b.blocker = :user1 AND b.blocked = :user2) " +
           "OR (b.blocker = :user2 AND b.blocked = :user1)")
    boolean isBlockedBetween(@Param("user1") User user1, @Param("user2") User user2);

    void deleteByBlockerAndBlocked(User blocker, User blocked);

    @Query("SELECT b.blocked.id FROM BlockedUser b WHERE b.blocker = :user " +
           "UNION SELECT b.blocker.id FROM BlockedUser b WHERE b.blocked = :user")
    Set<UUID> findBlockedUserIds(@Param("user") User user);
}
