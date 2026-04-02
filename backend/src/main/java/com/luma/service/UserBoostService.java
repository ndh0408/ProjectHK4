package com.luma.service;

import com.luma.dto.request.userboost.CreateUserBoostRequest;
import com.luma.dto.response.userboost.UserBoostPackageInfo;
import com.luma.dto.response.userboost.UserBoostResponse;
import com.luma.entity.Event;
import com.luma.entity.User;
import com.luma.entity.UserBoost;
import com.luma.entity.enums.BoostStatus;
import com.luma.entity.enums.EventStatus;
import com.luma.entity.enums.UserBoostPackage;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.EventRepository;
import com.luma.repository.UserBoostRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class UserBoostService {

    private final UserBoostRepository boostRepository;
    private final EventRepository eventRepository;

    public List<UserBoostPackageInfo> getAvailablePackages() {
        return Arrays.stream(UserBoostPackage.values())
                .map(UserBoostPackageInfo::fromEnum)
                .collect(Collectors.toList());
    }

    @Transactional
    public UserBoostResponse createBoost(CreateUserBoostRequest request, User user) {
        Event event = eventRepository.findById(request.getEventId())
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));

        if (!event.getOrganiser().getId().equals(user.getId())) {
            throw new BadRequestException("You can only boost your own events");
        }

        if (event.getStatus() != EventStatus.PUBLISHED && event.getStatus() != EventStatus.DRAFT) {
            throw new BadRequestException("Only draft or published events can be boosted");
        }

        if (event.getStartTime().isBefore(LocalDateTime.now())) {
            throw new BadRequestException("Cannot boost past events");
        }

        if (boostRepository.hasActiveBoost(event.getId(), LocalDateTime.now())) {
            throw new BadRequestException("Event already has an active boost");
        }

        UserBoostPackage pkg = request.getBoostPackage();

        UserBoost boost = UserBoost.builder()
                .event(event)
                .user(user)
                .boostPackage(pkg)
                .status(BoostStatus.PENDING)
                .amount(pkg.getPrice())
                .build();

        boost = boostRepository.save(boost);
        log.info("User boost created for event {} with package {}", event.getId(), pkg);

        return UserBoostResponse.fromEntity(boost);
    }

    @Transactional
    public UserBoostResponse activateBoost(UUID boostId, String paymentIntentId) {
        UserBoost boost = boostRepository.findById(boostId)
                .orElseThrow(() -> new ResourceNotFoundException("Boost not found"));

        if (boost.getStatus() != BoostStatus.PENDING) {
            throw new BadRequestException("Boost is not in pending status");
        }

        LocalDateTime now = LocalDateTime.now();
        boost.setStatus(BoostStatus.ACTIVE);
        boost.setPaymentIntentId(paymentIntentId);
        boost.setPaidAt(now);
        boost.setStartTime(now);
        boost.setEndTime(now.plusDays(boost.getBoostPackage().getDurationDays()));

        boost = boostRepository.save(boost);
        log.info("User boost activated: {} for event {}", boostId, boost.getEvent().getId());

        return UserBoostResponse.fromEntity(boost);
    }

    @Transactional
    public UserBoostResponse createBoostAfterPayment(CreateUserBoostRequest request, User user, String paymentIntentId) {
        Event event = eventRepository.findById(request.getEventId())
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));

        if (!event.getOrganiser().getId().equals(user.getId())) {
            throw new BadRequestException("You can only boost your own events");
        }

        if (event.getStartTime().isBefore(LocalDateTime.now())) {
            throw new BadRequestException("Cannot boost past events");
        }

        if (boostRepository.hasActiveBoost(event.getId(), LocalDateTime.now())) {
            throw new BadRequestException("Event already has an active boost");
        }

        UserBoostPackage pkg = request.getBoostPackage();
        LocalDateTime now = LocalDateTime.now();

        UserBoost boost = UserBoost.builder()
                .event(event)
                .user(user)
                .boostPackage(pkg)
                .status(BoostStatus.ACTIVE)
                .amount(pkg.getPrice())
                .paymentIntentId(paymentIntentId)
                .paidAt(now)
                .startTime(now)
                .endTime(now.plusDays(pkg.getDurationDays()))
                .build();

        boost = boostRepository.save(boost);
        log.info("User boost created and activated for event {} with package {}", event.getId(), pkg);

        return UserBoostResponse.fromEntity(boost);
    }

    @Transactional
    public void cancelBoost(UUID boostId, User user) {
        UserBoost boost = boostRepository.findById(boostId)
                .orElseThrow(() -> new ResourceNotFoundException("Boost not found"));

        if (!boost.getUser().getId().equals(user.getId())) {
            throw new BadRequestException("You can only cancel your own boosts");
        }

        if (boost.getStatus() == BoostStatus.ACTIVE) {
            throw new BadRequestException("Cannot cancel active boost. Contact support for refund.");
        }

        if (boost.getStatus() == BoostStatus.PENDING) {
            boostRepository.delete(boost);
            log.info("User boost {} deleted (was pending)", boostId);
        } else {
            boost.setStatus(BoostStatus.CANCELLED);
            boostRepository.save(boost);
            log.info("User boost {} cancelled", boostId);
        }
    }

    public Page<UserBoostResponse> getUserBoosts(UUID userId, BoostStatus status, Pageable pageable) {
        Page<UserBoost> boosts;
        if (status != null) {
            boosts = boostRepository.findByUserIdAndStatus(userId, status, pageable);
        } else {
            boosts = boostRepository.findByUserId(userId, pageable);
        }
        return boosts.map(UserBoostResponse::fromEntity);
    }

    public UserBoostResponse getBoostById(UUID boostId) {
        UserBoost boost = boostRepository.findById(boostId)
                .orElseThrow(() -> new ResourceNotFoundException("Boost not found"));
        return UserBoostResponse.fromEntity(boost);
    }

    public boolean isEventBoosted(UUID eventId) {
        return boostRepository.hasActiveBoost(eventId, LocalDateTime.now());
    }

    public UserBoostPackage getEventBoostPackage(UUID eventId) {
        return boostRepository.findActiveBoostsByEventId(eventId, LocalDateTime.now())
                .stream()
                .findFirst()
                .map(UserBoost::getBoostPackage)
                .orElse(null);
    }

    public List<UUID> getBoostedEventIds() {
        return boostRepository.findBoostedEventIds(LocalDateTime.now());
    }

    @Transactional
    public void updateBoostStats(UUID eventId, int views, int clicks) {
        boostRepository.findActiveBoostsByEventId(eventId, LocalDateTime.now())
                .stream()
                .findFirst()
                .ifPresent(boost -> {
                    boost.setViewsDuringBoost(boost.getViewsDuringBoost() + views);
                    boost.setClicksDuringBoost(boost.getClicksDuringBoost() + clicks);
                    boostRepository.save(boost);
                });
    }

    @Scheduled(fixedRate = 60000)
    @Transactional
    public void expireBoosts() {
        int expired = boostRepository.expireBoosts(LocalDateTime.now());
        if (expired > 0) {
            log.info("Expired {} user boosts", expired);
        }
    }
}
