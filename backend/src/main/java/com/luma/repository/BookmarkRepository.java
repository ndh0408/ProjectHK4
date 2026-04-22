package com.luma.repository;

import com.luma.entity.Bookmark;
import com.luma.entity.Event;
import com.luma.entity.User;
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
public interface BookmarkRepository extends JpaRepository<Bookmark, UUID> {

    Optional<Bookmark> findByUserAndEvent(User user, Event event);

    boolean existsByUserAndEvent(User user, Event event);

    @Query("SELECT b FROM Bookmark b WHERE b.user = :user ORDER BY b.createdAt DESC")
    Page<Bookmark> findByUser(@Param("user") User user, Pageable pageable);

    @Query("SELECT b.event.id FROM Bookmark b WHERE b.user = :user")
    List<UUID> findEventIdsByUser(@Param("user") User user);

    void deleteByUserAndEvent(User user, Event event);

    long countByUser(User user);

    long countByEvent(Event event);

    Optional<Bookmark> findByUserIdAndEventId(UUID userId, UUID eventId);
}
