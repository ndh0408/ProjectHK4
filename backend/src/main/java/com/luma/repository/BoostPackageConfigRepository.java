package com.luma.repository;

import com.luma.entity.BoostPackageConfig;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface BoostPackageConfigRepository extends JpaRepository<BoostPackageConfig, String> {
    List<BoostPackageConfig> findAllByOrderBySortOrderAscPackageKeyAsc();
    List<BoostPackageConfig> findAllByActiveTrueOrderBySortOrderAscPackageKeyAsc();
}
