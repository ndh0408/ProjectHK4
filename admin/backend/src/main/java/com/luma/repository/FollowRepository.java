package com.luma.repository;

import com.luma.entity.Follow;
import com.luma.entity.OrganiserProfile;
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
public interface FollowRepository extends JpaRepository<Follow, UUID> {

    Optional<Follow> findByFollowerAndOrganiser(User follower, OrganiserProfile organiser);

    boolean existsByFollowerAndOrganiser(User follower, OrganiserProfile organiser);

    Page<Follow> findByFollower(User follower, Pageable pageable);

    Page<Follow> findByOrganiser(OrganiserProfile organiser, Pageable pageable);

    long countByOrganiser(OrganiserProfile organiser);

    void deleteByFollowerAndOrganiser(User follower, OrganiserProfile organiser);

    @Query("SELECT COUNT(f) FROM Follow f WHERE f.organiser.user = :organiser")
    long countByOrganiser(@Param("organiser") User organiser);

    @Query("SELECT f FROM Follow f WHERE f.organiser.user = :organiser")
    Page<Follow> findByOrganiserUser(@Param("organiser") User organiser, Pageable pageable);

    @Query("SELECT f FROM Follow f WHERE f.organiser.user = :organiser")
    java.util.List<Follow> findAllByOrganiserUser(@Param("organiser") User organiser);
}
