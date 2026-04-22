package com.luma.repository;

import com.luma.entity.SubscriptionPlanConfig;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface SubscriptionPlanConfigRepository extends JpaRepository<SubscriptionPlanConfig, String> {
    List<SubscriptionPlanConfig> findAllByOrderBySortOrderAscPlanKeyAsc();
    List<SubscriptionPlanConfig> findAllByActiveTrueOrderBySortOrderAscPlanKeyAsc();
}
