package com.luma.service;

import com.luma.dto.request.BoostPackageConfigUpdateRequest;
import com.luma.entity.BoostPackageConfig;
import com.luma.entity.enums.BoostPackage;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.BoostPackageConfigRepository;
import com.luma.repository.EventBoostRepository;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class BoostPackageConfigService {

    private final BoostPackageConfigRepository repository;
    private final EventBoostRepository boostRepository;

    /** Seed the four canonical enum-backed tiers on first boot. Admins can edit pricing
     * later; they can also add custom tiers with any key via createCustom(). */
    @PostConstruct
    @Transactional
    public void seedDefaults() {
        int sort = 0;
        for (BoostPackage pkg : new BoostPackage[]{BoostPackage.VIP, BoostPackage.PREMIUM,
                                                   BoostPackage.STANDARD, BoostPackage.BASIC}) {
            if (!repository.existsById(pkg.name())) {
                BoostPackageConfig cfg = BoostPackageConfig.builder()
                        .packageKey(pkg.name())
                        .displayName(pkg.getDisplayName())
                        .priceUsd(pkg.getPrice())
                        .durationDays(pkg.getDurationDays())
                        .boostMultiplier(pkg.getBoostMultiplier())
                        .badgeText(pkg.getBadgeText())
                        .featuredInCategory(pkg.isFeaturedInCategory())
                        .featuredOnHome(pkg.isFeaturedOnHome())
                        .priorityInSearch(pkg.isPriorityInSearch())
                        .homeBanner(pkg.isHomeBanner())
                        .active(true)
                        .sortOrder(sort)
                        .build();
                repository.save(cfg);
                log.info("Seeded BoostPackageConfig for {}", pkg);
            }
            sort++;
        }
    }

    @Transactional(readOnly = true)
    public List<BoostPackageConfig> listAll() {
        return repository.findAllByOrderBySortOrderAscPackageKeyAsc();
    }

    @Transactional(readOnly = true)
    public List<BoostPackageConfig> listActive() {
        return repository.findAllByActiveTrueOrderBySortOrderAscPackageKeyAsc();
    }

    @Transactional(readOnly = true)
    public BoostPackageConfig get(String key) {
        return repository.findById(key)
                .orElseThrow(() -> new ResourceNotFoundException("Boost package not found: " + key));
    }

    @Transactional(readOnly = true)
    public BigDecimal getPriceOrDefault(BoostPackage key) {
        return repository.findById(key.name())
                .map(BoostPackageConfig::getPriceUsd)
                .orElse(key.getPrice());
    }

    @Transactional(readOnly = true)
    public int getDurationDaysOrDefault(BoostPackage key) {
        return repository.findById(key.name())
                .map(BoostPackageConfig::getDurationDays)
                .orElse(key.getDurationDays());
    }

    @Transactional(readOnly = true)
    public boolean isDiscountEligible(BoostPackage key) {
        return repository.findById(key.name())
                .map(cfg -> Boolean.TRUE.equals(cfg.getDiscountEligible()))
                .orElse(true);
    }

    /** Keys of ACTIVE config rows flagged for the Home VIP banner. Empty if admin hid all. */
    @Transactional(readOnly = true)
    public Set<String> activeHomeBannerKeys() {
        return listActive().stream()
                .filter(c -> Boolean.TRUE.equals(c.getHomeBanner()))
                .map(BoostPackageConfig::getPackageKey)
                .collect(Collectors.toSet());
    }

    /** Keys of ACTIVE config rows that should surface in the Home Featured & Boosted row. */
    @Transactional(readOnly = true)
    public Set<String> activeFeaturedKeys() {
        return listActive().stream()
                .filter(c -> Boolean.TRUE.equals(c.getFeaturedOnHome())
                        || Boolean.TRUE.equals(c.getFeaturedInCategory()))
                .map(BoostPackageConfig::getPackageKey)
                .collect(Collectors.toSet());
    }

    @Transactional
    public BoostPackageConfig create(String key, BoostPackageConfigUpdateRequest req) {
        String normalized = key == null ? null : key.trim().toUpperCase();
        if (normalized == null || normalized.isBlank()) {
            throw new BadRequestException("Package key is required");
        }
        if (!normalized.matches("^[A-Z0-9_]{2,40}$")) {
            throw new BadRequestException("Package key must be uppercase letters / digits / underscore (2-40 chars)");
        }
        if (repository.existsById(normalized)) {
            throw new BadRequestException("Package '" + normalized + "' already exists — use Edit instead");
        }
        String displayName = req.getDisplayName() == null ? "" : req.getDisplayName().trim();
        if (displayName.isBlank()) {
            throw new BadRequestException("Display name is required");
        }
        BoostPackageConfig cfg = BoostPackageConfig.builder()
                .packageKey(normalized)
                .displayName(displayName)
                .priceUsd(req.getPriceUsd())
                .durationDays(req.getDurationDays())
                .boostMultiplier(req.getBoostMultiplier())
                .badgeText(req.getBadgeText())
                .featuredInCategory(Boolean.TRUE.equals(req.getFeaturedInCategory()))
                .featuredOnHome(Boolean.TRUE.equals(req.getFeaturedOnHome()))
                .priorityInSearch(Boolean.TRUE.equals(req.getPriorityInSearch()))
                .homeBanner(Boolean.TRUE.equals(req.getHomeBanner()))
                .active(req.getActive() == null ? true : req.getActive())
                .discountEligible(req.getDiscountEligible() == null ? true : req.getDiscountEligible())
                .sortOrder(req.getSortOrder() == null ? 100 : req.getSortOrder())
                .build();
        BoostPackageConfig saved = repository.save(cfg);
        log.info("Admin created BoostPackageConfig {}: ${} / {}d", normalized, saved.getPriceUsd(), saved.getDurationDays());
        return saved;
    }

    @Transactional
    public BoostPackageConfig update(String key, BoostPackageConfigUpdateRequest req) {
        BoostPackageConfig cfg = get(key);
        String displayName = req.getDisplayName() == null ? "" : req.getDisplayName().trim();
        if (displayName.isBlank()) {
            throw new BadRequestException("Display name is required");
        }
        cfg.setDisplayName(displayName);
        cfg.setPriceUsd(req.getPriceUsd());
        cfg.setDurationDays(req.getDurationDays());
        cfg.setBoostMultiplier(req.getBoostMultiplier());
        cfg.setBadgeText(req.getBadgeText());
        if (req.getFeaturedInCategory() != null) cfg.setFeaturedInCategory(req.getFeaturedInCategory());
        if (req.getFeaturedOnHome() != null) cfg.setFeaturedOnHome(req.getFeaturedOnHome());
        if (req.getPriorityInSearch() != null) cfg.setPriorityInSearch(req.getPriorityInSearch());
        if (req.getHomeBanner() != null) cfg.setHomeBanner(req.getHomeBanner());
        if (req.getActive() != null) cfg.setActive(req.getActive());
        if (req.getDiscountEligible() != null) cfg.setDiscountEligible(req.getDiscountEligible());
        if (req.getSortOrder() != null) cfg.setSortOrder(req.getSortOrder());
        BoostPackageConfig saved = repository.save(cfg);
        log.info("Admin updated BoostPackageConfig {}: ${} / {}d / active={} / discountEligible={}",
                key, saved.getPriceUsd(), saved.getDurationDays(), saved.getActive(), saved.getDiscountEligible());
        return saved;
    }

    @Transactional
    public void delete(String key) {
        BoostPackageConfig cfg = get(key);
        // Guard: never delete a canonical enum tier (code switches on BoostPackage enum).
        // Admin can instead toggle `active=false` to hide it.
        for (BoostPackage canonical : BoostPackage.values()) {
            if (canonical.name().equals(cfg.getPackageKey())) {
                throw new BadRequestException(
                        "Canonical tier " + key + " cannot be deleted — set Active=false to hide it");
            }
        }
        repository.delete(cfg);
        log.info("Admin deleted BoostPackageConfig {}", key);
    }
}
