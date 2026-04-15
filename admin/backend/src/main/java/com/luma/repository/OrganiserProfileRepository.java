package com.luma.repository;

import com.luma.entity.OrganiserProfile;
import com.luma.entity.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface OrganiserProfileRepository extends JpaRepository<OrganiserProfile, UUID> {

    Optional<OrganiserProfile> findByUser(User user);

    Optional<OrganiserProfile> findByUserId(UUID userId);

    boolean existsByUser(User user);

    Page<OrganiserProfile> findByVerifiedTrue(Pageable pageable);

    @Query("SELECT op FROM OrganiserProfile op WHERE op.user.role = com.luma.entity.enums.UserRole.ORGANISER ORDER BY op.totalEvents DESC")
    List<OrganiserProfile> findTopOrganisersByEventCount(Pageable pageable);

    @Query("SELECT op FROM OrganiserProfile op WHERE op.user.role = com.luma.entity.enums.UserRole.ORGANISER ORDER BY op.totalFollowers DESC")
    List<OrganiserProfile> findTopOrganisersByFollowers(Pageable pageable);

    @Query("SELECT op FROM OrganiserProfile op WHERE " +
           "LOWER(op.displayName) LIKE LOWER(CONCAT('%', :query, '%'))")
    Page<OrganiserProfile> searchByDisplayName(String query, Pageable pageable);

    long countByVerifiedTrue();

    long countByVerifiedFalse();
}
