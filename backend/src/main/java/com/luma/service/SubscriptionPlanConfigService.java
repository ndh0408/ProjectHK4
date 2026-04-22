package com.luma.service;

import com.luma.dto.request.SubscriptionPlanConfigUpdateRequest;
import com.luma.entity.SubscriptionPlanConfig;
import com.luma.entity.enums.SubscriptionPlan;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.SubscriptionPlanConfigRepository;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
public class SubscriptionPlanConfigService {

    private final SubscriptionPlanConfigRepository repository;

    @PostConstruct
    @Transactional
    public void seedDefaults() {
        int sort = 0;
        for (SubscriptionPlan plan : new SubscriptionPlan[]{SubscriptionPlan.FREE,
                SubscriptionPlan.STANDARD, SubscriptionPlan.PREMIUM, SubscriptionPlan.VIP}) {
            if (!repository.existsById(plan.name())) {
                SubscriptionPlanConfig cfg = SubscriptionPlanConfig.builder()
                        .planKey(plan.name())
                        .displayName(plan.getDisplayName())
                        .monthlyPriceUsd(plan.getMonthlyPrice())
                        .maxEventsPerMonth(plan.getMaxEventsPerMonth())
                        .boostDiscountPercent(plan.getBoostDiscountPercent())
                        .active(true)
                        .sortOrder(sort)
                        .build();
                repository.save(cfg);
                log.info("Seeded SubscriptionPlanConfig for {}", plan);
            }
            sort++;
        }
    }

    @Transactional(readOnly = true)
    public List<SubscriptionPlanConfig> listAll() {
        return repository.findAllByOrderBySortOrderAscPlanKeyAsc();
    }

    @Transactional(readOnly = true)
    public List<SubscriptionPlanConfig> listActive() {
        return repository.findAllByActiveTrueOrderBySortOrderAscPlanKeyAsc();
    }

    @Transactional(readOnly = true)
    public SubscriptionPlanConfig get(String key) {
        return repository.findById(key)
                .orElseThrow(() -> new ResourceNotFoundException("Subscription plan not found: " + key));
    }

    @Transactional(readOnly = true)
    public BigDecimal getMonthlyPriceOrDefault(SubscriptionPlan key) {
        return repository.findById(key.name())
                .map(SubscriptionPlanConfig::getMonthlyPriceUsd)
                .orElse(key.getMonthlyPrice());
    }

    @Transactional(readOnly = true)
    public int getBoostDiscountPercentOrDefault(SubscriptionPlan key) {
        return repository.findById(key.name())
                .map(SubscriptionPlanConfig::getBoostDiscountPercent)
                .orElse(key.getBoostDiscountPercent());
    }

    @Transactional(readOnly = true)
    public int getMaxEventsPerMonthOrDefault(SubscriptionPlan key) {
        return repository.findById(key.name())
                .map(SubscriptionPlanConfig::getMaxEventsPerMonth)
                .orElse(key.getMaxEventsPerMonth());
    }

    @Transactional
    public SubscriptionPlanConfig create(String key, SubscriptionPlanConfigUpdateRequest req) {
        String normalized = key == null ? null : key.trim().toUpperCase();
        if (normalized == null || normalized.isBlank()) {
            throw new BadRequestException("Plan key is required");
        }
        if (!normalized.matches("^[A-Z0-9_]{2,40}$")) {
            throw new BadRequestException("Plan key must be uppercase letters / digits / underscore (2-40 chars)");
        }
        if (repository.existsById(normalized)) {
            throw new BadRequestException("Plan '" + normalized + "' already exists — use Edit");
        }
        SubscriptionPlanConfig cfg = SubscriptionPlanConfig.builder()
                .planKey(normalized)
                .displayName(req.getDisplayName())
                .monthlyPriceUsd(req.getMonthlyPriceUsd())
                .maxEventsPerMonth(req.getMaxEventsPerMonth())
                .boostDiscountPercent(req.getBoostDiscountPercent())
                .active(req.getActive() == null ? true : req.getActive())
                .sortOrder(req.getSortOrder() == null ? 100 : req.getSortOrder())
                .build();
        return repository.save(cfg);
    }

    @Transactional
    public SubscriptionPlanConfig update(String key, SubscriptionPlanConfigUpdateRequest req) {
        SubscriptionPlanConfig cfg = get(key);
        cfg.setDisplayName(req.getDisplayName());
        cfg.setMonthlyPriceUsd(req.getMonthlyPriceUsd());
        cfg.setMaxEventsPerMonth(req.getMaxEventsPerMonth());
        cfg.setBoostDiscountPercent(req.getBoostDiscountPercent());
        if (req.getActive() != null) cfg.setActive(req.getActive());
        if (req.getSortOrder() != null) cfg.setSortOrder(req.getSortOrder());
        SubscriptionPlanConfig saved = repository.save(cfg);
        log.info("Admin updated SubscriptionPlanConfig {}: ${}/mo / max={} events / discount={}% / active={}",
                key, saved.getMonthlyPriceUsd(), saved.getMaxEventsPerMonth(),
                saved.getBoostDiscountPercent(), saved.getActive());
        return saved;
    }

    @Transactional
    public void delete(String key) {
        SubscriptionPlanConfig cfg = get(key);
        for (SubscriptionPlan canonical : SubscriptionPlan.values()) {
            if (canonical.name().equals(cfg.getPlanKey())) {
                throw new BadRequestException(
                        "Canonical plan " + key + " cannot be deleted — set Active=false to hide it");
            }
        }
        repository.delete(cfg);
    }
}
