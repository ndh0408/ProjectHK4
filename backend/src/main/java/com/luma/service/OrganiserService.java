package com.luma.service;

import com.luma.dto.request.OrganiserProfileRequest;
import com.luma.dto.response.OrganiserResponse;
import com.luma.dto.response.PageResponse;
import com.luma.entity.OrganiserProfile;
import com.luma.entity.User;
import com.luma.entity.enums.UserRole;
import com.luma.entity.enums.UserStatus;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.EventRepository;
import com.luma.repository.FollowRepository;
import com.luma.repository.OrganiserProfileRepository;
import com.luma.repository.RegistrationRepository;
import com.luma.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class OrganiserService {

    private final OrganiserProfileRepository organiserProfileRepository;
    private final UserRepository userRepository;
    private final RegistrationRepository registrationRepository;
    private final EventRepository eventRepository;
    private final FollowRepository followRepository;

    public OrganiserProfile getEntityByUserId(UUID userId) {
        return organiserProfileRepository.findByUserId(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Organiser profile not found"));
    }

    @Transactional
    public OrganiserResponse getOrganiserProfile(UUID userId) {
        OrganiserProfile profile = organiserProfileRepository.findByUserId(userId).orElse(null);

        if (profile == null) {
            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new ResourceNotFoundException("User not found"));

            long eventCount = eventRepository.countByOrganiser(user);
            if (eventCount > 0) {
                profile = autoCreateOrganiserProfile(user);
                log.info("Auto-created OrganiserProfile for user {} who has {} events", userId, eventCount);
            } else {
                throw new ResourceNotFoundException("Organiser profile not found");
            }
        }

        User user = profile.getUser();

        long totalEvents = eventRepository.countByOrganiser(user);
        long totalFollowers = followRepository.countByOrganiser(user);
        long totalRegistrations = registrationRepository.countApprovedByOrganiser(user);

        return OrganiserResponse.fromEntityWithAllStats(profile, totalEvents, totalFollowers, totalRegistrations);
    }

    private OrganiserProfile autoCreateOrganiserProfile(User user) {
        String displayName = user.getFullName();
        if (displayName == null || displayName.isEmpty()) {
            displayName = user.getEmail() != null ? user.getEmail().split("@")[0] : "Organiser";
        }

        OrganiserProfile profile = OrganiserProfile.builder()
                .user(user)
                .displayName(displayName)
                .bio(null)
                .logoUrl(user.getAvatarUrl())
                .website(null)
                .contactEmail(user.getEmail())
                .contactPhone(user.getPhone())
                .build();

        return organiserProfileRepository.save(profile);
    }

    public OrganiserResponse getOrganiserProfileByUser(User user) {
        OrganiserProfile profile = organiserProfileRepository.findByUser(user)
                .orElseThrow(() -> new ResourceNotFoundException("You do not have an organiser profile"));

        long totalEvents = eventRepository.countByOrganiser(user);
        long totalFollowers = followRepository.countByOrganiser(user);
        long totalRegistrations = registrationRepository.countApprovedByOrganiser(user);

        return OrganiserResponse.fromEntityWithAllStats(profile, totalEvents, totalFollowers, totalRegistrations);
    }

    @Transactional
    public OrganiserResponse createOrganiserProfile(User user, OrganiserProfileRequest request) {
        if (organiserProfileRepository.existsByUser(user)) {
            throw new BadRequestException("You already have an organiser profile");
        }

        OrganiserProfile profile = OrganiserProfile.builder()
                .user(user)
                .displayName(request.getDisplayName())
                .bio(request.getBio())
                .logoUrl(request.getLogoUrl())
                .website(request.getWebsite())
                .contactEmail(request.getContactEmail())
                .contactPhone(request.getContactPhone())
                .build();

        user.setRole(UserRole.ORGANISER);
        userRepository.save(user);

        return OrganiserResponse.fromEntity(organiserProfileRepository.save(profile));
    }

    @Transactional
    public OrganiserResponse updateOrganiserProfile(User user, OrganiserProfileRequest request) {
        OrganiserProfile profile = organiserProfileRepository.findByUser(user)
                .orElseThrow(() -> new ResourceNotFoundException("You do not have an organiser profile"));

        if (request.getDisplayName() != null) profile.setDisplayName(request.getDisplayName());
        if (request.getBio() != null) profile.setBio(request.getBio());
        if (request.getLogoUrl() != null) profile.setLogoUrl(request.getLogoUrl());
        if (request.getWebsite() != null) profile.setWebsite(request.getWebsite());
        if (request.getContactEmail() != null) profile.setContactEmail(request.getContactEmail());
        if (request.getContactPhone() != null) profile.setContactPhone(request.getContactPhone());

        return OrganiserResponse.fromEntity(organiserProfileRepository.save(profile));
    }

    public PageResponse<OrganiserResponse> getAllOrganiserProfiles(Pageable pageable) {
        Page<OrganiserProfile> profiles = organiserProfileRepository.findAll(pageable);
        return PageResponse.from(profiles, profile -> {
            User user = profile.getUser();
            long totalEvents = eventRepository.countByOrganiser(user);
            long totalFollowers = followRepository.countByOrganiser(user);
            long totalRegistrations = registrationRepository.countApprovedByOrganiser(user);
            return OrganiserResponse.fromEntityWithAllStats(profile, totalEvents, totalFollowers, totalRegistrations);
        });
    }

    public List<OrganiserResponse> getFeaturedOrganisers() {
        return organiserProfileRepository.findTopOrganisersByEventCount(PageRequest.of(0, 10))
                .stream()
                .map(profile -> {
                    User user = profile.getUser();
                    long totalEvents = eventRepository.countByOrganiser(user);
                    long totalFollowers = followRepository.countByOrganiser(user);
                    long totalRegistrations = registrationRepository.countApprovedByOrganiser(user);
                    return OrganiserResponse.fromEntityWithAllStats(profile, totalEvents, totalFollowers, totalRegistrations);
                })
                .toList();
    }

    @Transactional
    public OrganiserResponse verifyOrganiser(UUID userId) {
        OrganiserProfile profile = getEntityByUserId(userId);
        profile.setVerified(true);
        return OrganiserResponse.fromEntity(organiserProfileRepository.save(profile));
    }

    @Transactional
    public OrganiserResponse unverifyOrganiser(UUID userId) {
        OrganiserProfile profile = getEntityByUserId(userId);
        profile.setVerified(false);
        return OrganiserResponse.fromEntity(organiserProfileRepository.save(profile));
    }

    @Transactional
    public void incrementTotalEvents(OrganiserProfile profile) {
        profile.setTotalEvents(profile.getTotalEvents() + 1);
        organiserProfileRepository.save(profile);
    }

    @Transactional
    public void incrementFollowers(OrganiserProfile profile) {
        profile.setTotalFollowers(profile.getTotalFollowers() + 1);
        organiserProfileRepository.save(profile);
    }

    @Transactional
    public void decrementFollowers(OrganiserProfile profile) {
        if (profile.getTotalFollowers() > 0) {
            profile.setTotalFollowers(profile.getTotalFollowers() - 1);
            organiserProfileRepository.save(profile);
        }
    }

    @Transactional
    public OrganiserResponse updateOrganiserStatus(UUID userId, UserStatus status) {
        OrganiserProfile profile = getEntityByUserId(userId);
        User user = profile.getUser();
        user.setStatus(status);
        userRepository.save(user);
        return OrganiserResponse.fromEntity(profile);
    }

    @Transactional
    public OrganiserResponse updateOrganiserLogo(User user, String logoUrl) {
        OrganiserProfile profile = organiserProfileRepository.findByUser(user)
                .orElseThrow(() -> new ResourceNotFoundException("You do not have an organiser profile"));
        profile.setLogoUrl(logoUrl);
        return OrganiserResponse.fromEntity(organiserProfileRepository.save(profile));
    }

    @Transactional
    public OrganiserResponse updateOrganiserCover(User user, String coverUrl) {
        OrganiserProfile profile = organiserProfileRepository.findByUser(user)
                .orElseThrow(() -> new ResourceNotFoundException("You do not have an organiser profile"));
        profile.setCoverUrl(coverUrl);
        return OrganiserResponse.fromEntity(organiserProfileRepository.save(profile));
    }

    @Transactional
    public OrganiserResponse updateOrganiserSignature(User user, String signatureUrl) {
        OrganiserProfile profile = organiserProfileRepository.findByUser(user)
                .orElseThrow(() -> new ResourceNotFoundException("You do not have an organiser profile"));
        // Signature is stored in User entity
        user.setSignatureUrl(signatureUrl);
        userRepository.save(user);
        return OrganiserResponse.fromEntity(profile);
    }
}
