package com.luma.service;

import com.luma.dto.request.OrganiserProfileRequest;
import com.luma.dto.response.OrganiserResponse;
import com.luma.dto.response.PageResponse;
import com.luma.entity.Event;
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

import java.util.Comparator;
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
        OrganiserProfile profile = organiserProfileRepository.findByUserId(userId).orElse(null);
        if (profile != null) {
            return profile;
        }

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
        return getOrCreateOrganiserProfile(user);
    }

    @Transactional
    public OrganiserResponse getOrganiserProfile(UUID userId) {
        return buildOrganiserResponse(getEntityByUserId(userId));
    }

    private OrganiserProfile autoCreateOrganiserProfile(User user) {
        String displayName = user.getFullName();
        if (displayName == null || displayName.isEmpty()) {
            displayName = user.getEmail() != null ? user.getEmail().split("@")[0] : "Organiser";
        }

        String featuredImageUrl = resolveFeaturedEventImage(user);

        OrganiserProfile profile = OrganiserProfile.builder()
                .user(user)
                .displayName(displayName)
                .bio(user.getBio())
                .logoUrl(firstNonBlank(user.getAvatarUrl(), featuredImageUrl))
                .coverUrl(firstNonBlank(featuredImageUrl, user.getAvatarUrl()))
                .website(null)
                .contactEmail(user.getEmail())
                .contactPhone(user.getPhone())
                .build();

        return organiserProfileRepository.save(profile);
    }

    private OrganiserProfile getOrCreateOrganiserProfile(User user) {
        OrganiserProfile existingProfile = organiserProfileRepository.findByUser(user).orElse(null);
        if (existingProfile != null) {
            return existingProfile;
        }

        long eventCount = eventRepository.countByOrganiser(user);
        if (user.getRole() != UserRole.ORGANISER && eventCount <= 0) {
            throw new ResourceNotFoundException("Organiser profile not found");
        }

        OrganiserProfile profile = autoCreateOrganiserProfile(user);
        log.info("Auto-created OrganiserProfile for user {} with role {} and {} events",
                user.getId(), user.getRole(), eventCount);
        return profile;
    }

    private OrganiserResponse buildOrganiserResponse(OrganiserProfile profile) {
        User user = profile.getUser();
        long totalEvents = eventRepository.countByOrganiser(user);
        long totalFollowers = followRepository.countByOrganiser(user);
        long totalRegistrations = registrationRepository.countApprovedByOrganiser(user);
        String featuredImageUrl = resolveFeaturedEventImage(user);

        OrganiserResponse response =
                OrganiserResponse.fromEntityWithAllStats(profile, totalEvents, totalFollowers, totalRegistrations);
        response.setDisplayName(firstNonBlank(
                profile.getDisplayName(),
                user.getFullName(),
                user.getEmail() != null ? user.getEmail().split("@")[0] : null,
                "Organiser"
        ));
        response.setOrganizationName(response.getDisplayName());
        response.setBio(firstNonBlank(profile.getBio(), user.getBio()));
        response.setLogoUrl(firstNonBlank(profile.getLogoUrl(), user.getAvatarUrl(), profile.getCoverUrl(), featuredImageUrl));
        response.setAvatarUrl(firstNonBlank(user.getAvatarUrl(), profile.getLogoUrl(), profile.getCoverUrl(), featuredImageUrl));
        response.setCoverUrl(firstNonBlank(profile.getCoverUrl(), featuredImageUrl, profile.getLogoUrl(), user.getAvatarUrl()));
        response.setWebsite(firstNonBlank(profile.getWebsite()));
        response.setContactEmail(firstNonBlank(profile.getContactEmail(), user.getEmail()));
        response.setContactPhone(firstNonBlank(profile.getContactPhone(), user.getPhone()));
        return response;
    }

    private String resolveFeaturedEventImage(User user) {
        return eventRepository.findTopEventsByOrganiser(user.getId(), PageRequest.of(0, 1)).stream()
                .map(Event::getImageUrl)
                .filter(imageUrl -> imageUrl != null && !imageUrl.isBlank())
                .findFirst()
                .orElse(null);
    }

    private String firstNonBlank(String... values) {
        for (String value : values) {
            if (value != null && !value.isBlank()) {
                return value;
            }
        }
        return null;
    }

    public OrganiserResponse getOrganiserProfileByUser(User user) {
        return buildOrganiserResponse(getOrCreateOrganiserProfile(user));
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
        if (request.getLogoUrl() != null && !request.getLogoUrl().isBlank()) {
            user.setAvatarUrl(request.getLogoUrl());
        }
        userRepository.save(user);

        return buildOrganiserResponse(organiserProfileRepository.save(profile));
    }

    @Transactional
    public OrganiserResponse updateOrganiserProfile(User user, OrganiserProfileRequest request) {
        OrganiserProfile profile = organiserProfileRepository.findByUser(user)
                .orElseThrow(() -> new ResourceNotFoundException("You do not have an organiser profile"));

        if (request.getDisplayName() != null) profile.setDisplayName(request.getDisplayName());
        if (request.getBio() != null) profile.setBio(request.getBio());
        if (request.getLogoUrl() != null) {
            profile.setLogoUrl(request.getLogoUrl());
            if (!request.getLogoUrl().isBlank()) {
                user.setAvatarUrl(request.getLogoUrl());
            }
        }
        if (request.getWebsite() != null) profile.setWebsite(request.getWebsite());
        if (request.getContactEmail() != null) profile.setContactEmail(request.getContactEmail());
        if (request.getContactPhone() != null) profile.setContactPhone(request.getContactPhone());

        userRepository.save(user);
        return buildOrganiserResponse(organiserProfileRepository.save(profile));
    }

    public PageResponse<OrganiserResponse> getAllOrganiserProfiles(Pageable pageable) {
        Page<User> organisers = userRepository.findByRole(UserRole.ORGANISER, pageable);
        return PageResponse.from(organisers, user -> buildOrganiserResponse(getOrCreateOrganiserProfile(user)));
    }

    @Transactional
    public List<OrganiserResponse> getFeaturedOrganisers() {
        return getPublicOrganisers().stream()
                .filter(response -> response.getTotalEvents() > 0)
                .limit(10)
                .toList();
    }

    @Transactional
    public List<OrganiserResponse> getPublicOrganisers() {
        return userRepository.findAllByRole(UserRole.ORGANISER).stream()
                .filter(user -> user.getStatus() == UserStatus.ACTIVE)
                .map(this::getOrCreateOrganiserProfile)
                .map(this::buildOrganiserResponse)
                .sorted(
                        Comparator.comparingInt(OrganiserResponse::getTotalEvents).reversed()
                                .thenComparing(
                                        Comparator.comparingInt(OrganiserResponse::getFollowersCount).reversed())
                                .thenComparing(
                                        OrganiserResponse::getDisplayName,
                                        String.CASE_INSENSITIVE_ORDER
                                )
                )
                .toList();
    }

    @Transactional
    public OrganiserResponse verifyOrganiser(UUID userId) {
        OrganiserProfile profile = getEntityByUserId(userId);
        profile.setVerified(true);
        return buildOrganiserResponse(organiserProfileRepository.save(profile));
    }

    @Transactional
    public OrganiserResponse unverifyOrganiser(UUID userId) {
        OrganiserProfile profile = getEntityByUserId(userId);
        profile.setVerified(false);
        return buildOrganiserResponse(organiserProfileRepository.save(profile));
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
        return buildOrganiserResponse(profile);
    }

    @Transactional
    public OrganiserResponse updateOrganiserLogo(User user, String logoUrl) {
        OrganiserProfile profile = getOrCreateOrganiserProfile(user);
        profile.setLogoUrl(logoUrl);
        user.setAvatarUrl(logoUrl);
        userRepository.save(user);
        return buildOrganiserResponse(organiserProfileRepository.save(profile));
    }

    @Transactional
    public OrganiserResponse updateOrganiserCover(User user, String coverUrl) {
        OrganiserProfile profile = getOrCreateOrganiserProfile(user);
        profile.setCoverUrl(coverUrl);
        return buildOrganiserResponse(organiserProfileRepository.save(profile));
    }

    @Transactional
    public OrganiserResponse updateOrganiserSignature(User user, String signatureUrl) {
        OrganiserProfile profile = getOrCreateOrganiserProfile(user);
        user.setSignatureUrl(signatureUrl);
        userRepository.save(user);
        return buildOrganiserResponse(profile);
    }
}
