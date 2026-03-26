package com.luma.repository;

import com.luma.entity.PlatformConfig;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface PlatformConfigRepository extends JpaRepository<PlatformConfig, UUID> {

    /**
     * Get the platform config (should only be one row)
     */
    @Query("SELECT pc FROM PlatformConfig pc ORDER BY pc.createdAt ASC LIMIT 1")
    Optional<PlatformConfig> findFirst();
}
