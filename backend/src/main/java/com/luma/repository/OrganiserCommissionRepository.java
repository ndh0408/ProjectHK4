package com.luma.repository;

import com.luma.entity.OrganiserCommission;
import com.luma.entity.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface OrganiserCommissionRepository extends JpaRepository<OrganiserCommission, UUID> {

    /**
     * Find custom commission for an organiser
     */
    Optional<OrganiserCommission> findByOrganiser(User organiser);

    Optional<OrganiserCommission> findByOrganiserId(UUID organiserId);

    /**
     * Find active and valid custom commission for an organiser
     */
    @Query("SELECT oc FROM OrganiserCommission oc " +
           "WHERE oc.organiser.id = :organiserId " +
           "AND oc.isActive = true " +
           "AND oc.effectiveFrom <= :now " +
           "AND (oc.effectiveUntil IS NULL OR oc.effectiveUntil >= :now)")
    Optional<OrganiserCommission> findValidCommissionForOrganiser(
            @Param("organiserId") UUID organiserId,
            @Param("now") LocalDateTime now);

    /**
     * Find all custom commissions (for admin)
     */
    Page<OrganiserCommission> findAllByOrderByCreatedAtDesc(Pageable pageable);

    /**
     * Find all active custom commissions
     */
    Page<OrganiserCommission> findByIsActiveTrueOrderByCreatedAtDesc(Pageable pageable);

    /**
     * Check if organiser has custom commission
     */
    boolean existsByOrganiserId(UUID organiserId);
}
