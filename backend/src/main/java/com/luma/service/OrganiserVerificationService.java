package com.luma.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.luma.dto.request.ApplyOrganiserRequest;
import com.luma.dto.request.ReviewVerificationRequest;
import com.luma.dto.request.SubmitVerificationRequest;
import com.luma.dto.response.PageResponse;
import com.luma.dto.response.VerificationRequestResponse;
import com.luma.entity.OrganiserProfile;
import com.luma.entity.OrganiserVerificationRequest;
import com.luma.entity.User;
import com.luma.entity.enums.UserRole;
import com.luma.entity.enums.UserStatus;
import com.luma.entity.enums.VerificationAiStatus;
import com.luma.entity.enums.VerificationDocumentType;
import com.luma.entity.enums.VerificationStatus;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.OrganiserProfileRepository;
import com.luma.repository.OrganiserVerificationRequestRepository;
import com.luma.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class OrganiserVerificationService {

    private final OrganiserVerificationRequestRepository requestRepository;
    private final OrganiserProfileRepository organiserProfileRepository;
    private final AIService aiService;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final EmailService emailService;

    private static final ObjectMapper MAPPER = new ObjectMapper();

    @Transactional
    public VerificationRequestResponse applyAsOrganiser(ApplyOrganiserRequest request) {
        String email = request.getEmail().trim().toLowerCase();
        User existing = userRepository.findByEmail(email).orElse(null);

        User user;
        if (existing == null) {
            if (request.getPhone() != null && !request.getPhone().isBlank()
                    && userRepository.existsByPhone(request.getPhone())) {
                throw new BadRequestException("Phone number is already in use");
            }

            user = User.builder()
                    .email(email)
                    .phone(request.getPhone())
                    .password(passwordEncoder.encode(request.getPassword()))
                    .fullName(request.getFullName())
                    .role(UserRole.USER)
                    .status(UserStatus.ACTIVE)
                    .emailVerified(true)
                    .build();
            user = userRepository.save(user);
        } else {
            if (existing.getRole() == UserRole.ORGANISER || existing.getRole() == UserRole.ADMIN) {
                throw new BadRequestException(
                        "This email is already registered as an organiser. Please login and request the badge from your profile.");
            }
            if (requestRepository.existsByOrganiserAndStatus(existing, VerificationStatus.PENDING)) {
                throw new BadRequestException(
                        "You already have a pending organiser application. Please wait for admin review.");
            }
            existing.setFullName(request.getFullName());
            existing.setPassword(passwordEncoder.encode(request.getPassword()));
            if (request.getPhone() != null && !request.getPhone().isBlank()) {
                existing.setPhone(request.getPhone());
            }
            existing.setEmailVerified(true);
            user = userRepository.save(existing);
        }

        List<String> urls = request.getDocumentUrls().stream()
                .filter(u -> u != null && !u.isBlank())
                .toList();
        if (urls.isEmpty()) {
            throw new BadRequestException("Please upload at least one Citizen ID image");
        }
        String urlsJson = serializeUrls(urls);

        OrganiserVerificationRequest entity = OrganiserVerificationRequest.builder()
                .organiser(user)
                .isApplication(true)
                .documentType(VerificationDocumentType.CITIZEN_ID)
                .documentUrls(urlsJson)
                .legalName(request.getLegalName())
                .documentNumber(request.getDocumentNumber())
                .organisationName(request.getOrganisationName())
                .organisationBio(request.getOrganisationBio())
                .organisationWebsite(request.getOrganisationWebsite())
                .organisationContactEmail(request.getOrganisationContactEmail())
                .organisationContactPhone(request.getOrganisationContactPhone())
                .status(VerificationStatus.PENDING)
                .build();

        applyAiPreCheck(entity, urls, VerificationDocumentType.CITIZEN_ID);

        OrganiserVerificationRequest saved = requestRepository.save(entity);
        log.info("New organiser application {} from user {} (AI: {})",
                saved.getId(), user.getId(), saved.getAiStatus());

        return VerificationRequestResponse.fromEntity(saved);
    }

    @Transactional
    public VerificationRequestResponse submit(User organiser, SubmitVerificationRequest request) {
        if (requestRepository.existsByOrganiserAndStatus(organiser, VerificationStatus.PENDING)) {
            throw new BadRequestException("You already have a pending verification request. Please wait for admin review.");
        }

        List<String> urls = request.getDocumentUrls().stream()
                .filter(u -> u != null && !u.isBlank())
                .toList();
        if (urls.isEmpty()) {
            throw new BadRequestException("At least one document image is required");
        }

        String urlsJson = serializeUrls(urls);

        OrganiserVerificationRequest entity = OrganiserVerificationRequest.builder()
                .organiser(organiser)
                .documentType(request.getDocumentType())
                .documentUrls(urlsJson)
                .legalName(request.getLegalName())
                .documentNumber(request.getDocumentNumber())
                .isApplication(false)
                .status(VerificationStatus.PENDING)
                .build();

        applyAiPreCheck(entity, urls, request.getDocumentType());

        OrganiserVerificationRequest saved = requestRepository.save(entity);
        log.info("Organiser {} submitted verification request {} (AI: {})",
                organiser.getId(), saved.getId(), saved.getAiStatus());

        return VerificationRequestResponse.fromEntity(saved);
    }

    private String serializeUrls(List<String> urls) {
        try {
            return MAPPER.writeValueAsString(urls);
        } catch (Exception e) {
            throw new BadRequestException("Invalid document URLs");
        }
    }

    private void applyAiPreCheck(OrganiserVerificationRequest entity, List<String> urls,
                                  com.luma.entity.enums.VerificationDocumentType documentType) {
        String aiRaw = aiService.analyzeVerificationDocument(urls, documentType);
        if (aiRaw == null || aiRaw.isBlank()) {
            entity.setAiStatus(VerificationAiStatus.UNAVAILABLE);
            entity.setAiReason("AI pre-check unavailable. Admin must review manually.");
            return;
        }

        try {
            JsonNode node = MAPPER.readTree(aiRaw);
            String statusStr = node.has("status") ? node.get("status").asText("").toUpperCase() : "";
            VerificationAiStatus aiStatus;
            switch (statusStr) {
                case "VALID" -> aiStatus = VerificationAiStatus.VALID;
                case "SUSPICIOUS" -> aiStatus = VerificationAiStatus.SUSPICIOUS;
                case "INVALID" -> aiStatus = VerificationAiStatus.INVALID;
                default -> aiStatus = VerificationAiStatus.UNAVAILABLE;
            }
            entity.setAiStatus(aiStatus);
            if (node.has("confidence") && node.get("confidence").isNumber()) {
                entity.setAiConfidence(node.get("confidence").asInt());
            }
            if (node.has("reason")) {
                entity.setAiReason(node.get("reason").asText());
            }
        } catch (Exception e) {
            log.warn("Failed to parse AI verification response: {}", e.getMessage());
            entity.setAiStatus(VerificationAiStatus.UNAVAILABLE);
            entity.setAiReason("AI pre-check parsing failed. Admin must review manually.");
        }
    }

    @Transactional(readOnly = true)
    public VerificationRequestResponse getMyLatest(User organiser) {
        return requestRepository.findTopByOrganiserOrderBySubmittedAtDesc(organiser)
                .map(VerificationRequestResponse::fromEntity)
                .orElse(null);
    }

    @Transactional(readOnly = true)
    public PageResponse<VerificationRequestResponse> listRequests(
            VerificationStatus status, Boolean isApplication, Pageable pageable) {
        Page<OrganiserVerificationRequest> page;
        if (status != null && isApplication != null) {
            page = requestRepository.findByStatusAndIsApplicationOrderBySubmittedAtAsc(status, isApplication, pageable);
        } else if (status != null) {
            page = requestRepository.findByStatusOrderBySubmittedAtAsc(status, pageable);
        } else if (isApplication != null) {
            page = requestRepository.findByIsApplicationOrderBySubmittedAtDesc(isApplication, pageable);
        } else {
            page = requestRepository.findAllByOrderBySubmittedAtDesc(pageable);
        }
        return PageResponse.from(page, VerificationRequestResponse::fromEntity);
    }

    @Transactional(readOnly = true)
    public long countPending() {
        return requestRepository.countByStatus(VerificationStatus.PENDING);
    }

    @Transactional(readOnly = true)
    public long countPendingApplications() {
        return requestRepository.countByStatusAndIsApplication(VerificationStatus.PENDING, true);
    }

    @Transactional(readOnly = true)
    public long countPendingBadgeRequests() {
        return requestRepository.countByStatusAndIsApplication(VerificationStatus.PENDING, false);
    }

    @Transactional
    public VerificationRequestResponse review(UUID requestId, User admin, ReviewVerificationRequest review) {
        OrganiserVerificationRequest request = requestRepository.findById(requestId)
                .orElseThrow(() -> new ResourceNotFoundException("Verification request not found"));

        if (request.getStatus() != VerificationStatus.PENDING) {
            throw new BadRequestException("This request has already been reviewed");
        }

        boolean approve = Boolean.TRUE.equals(review.getApprove());
        boolean grantBadgeInput = Boolean.TRUE.equals(review.getGrantVerifiedBadge());

        log.info("[VERIFICATION REVIEW] request={} admin={} approve={} grantVerifiedBadge={} isApplication={}",
                requestId, admin.getId(), approve, grantBadgeInput, request.isApplication());

        if (!approve && (review.getRejectReason() == null || review.getRejectReason().isBlank())) {
            throw new BadRequestException("Reject reason is required when rejecting a request");
        }

        if (approve && !request.isApplication() && !grantBadgeInput) {
            throw new BadRequestException(
                    "For badge requests, you must either grant the badge or reject the submission");
        }

        request.setStatus(approve ? VerificationStatus.APPROVED : VerificationStatus.REJECTED);
        request.setReviewedBy(admin);
        request.setReviewedAt(LocalDateTime.now());
        if (!approve) {
            request.setRejectReason(review.getRejectReason());
        }

        boolean grantBadge = grantBadgeInput;
        if (approve) {
            User organiser = request.getOrganiser();

            if (request.isApplication() && organiser.getRole() != UserRole.ORGANISER) {
                organiser.setRole(UserRole.ORGANISER);
                organiser.setEmailVerified(true);
                userRepository.save(organiser);
            }

            OrganiserProfile profile = organiserProfileRepository.findByUser(organiser).orElse(null);
            if (profile == null) {
                profile = OrganiserProfile.builder()
                        .user(organiser)
                        .displayName(firstNonBlank(
                                request.getOrganisationName(),
                                organiser.getFullName(),
                                organiser.getEmail() != null ? organiser.getEmail().split("@")[0] : "Organiser"))
                        .bio(request.getOrganisationBio())
                        .website(request.getOrganisationWebsite())
                        .contactEmail(firstNonBlank(request.getOrganisationContactEmail(), organiser.getEmail()))
                        .contactPhone(firstNonBlank(request.getOrganisationContactPhone(), organiser.getPhone()))
                        .verified(grantBadge)
                        .build();
            } else {
                // Application approval is authoritative over the badge flag — always set
                // verified to exactly the admin's decision (no sticky state from prior tests).
                // Badge-request approval only grants (never revokes) on this path.
                if (request.isApplication()) {
                    profile.setVerified(grantBadge);
                } else if (grantBadge) {
                    profile.setVerified(true);
                }
                if (request.isApplication()) {
                    if (isBlank(profile.getDisplayName()) && !isBlank(request.getOrganisationName())) {
                        profile.setDisplayName(request.getOrganisationName());
                    }
                    if (isBlank(profile.getBio()) && !isBlank(request.getOrganisationBio())) {
                        profile.setBio(request.getOrganisationBio());
                    }
                    if (isBlank(profile.getWebsite()) && !isBlank(request.getOrganisationWebsite())) {
                        profile.setWebsite(request.getOrganisationWebsite());
                    }
                    if (isBlank(profile.getContactEmail()) && !isBlank(request.getOrganisationContactEmail())) {
                        profile.setContactEmail(request.getOrganisationContactEmail());
                    }
                    if (isBlank(profile.getContactPhone()) && !isBlank(request.getOrganisationContactPhone())) {
                        profile.setContactPhone(request.getOrganisationContactPhone());
                    }
                }
            }
            organiserProfileRepository.save(profile);
            log.info("[VERIFICATION REVIEW RESULT] organiser={} profile.verified={} (application={}, grantBadge={})",
                    organiser.getId(), profile.isVerified(), request.isApplication(), grantBadge);

            try {
                if (request.isApplication()) {
                    if (grantBadge) {
                        emailService.sendOrganiserApplicationApprovedWithBadgeEmail(
                                organiser.getEmail(), organiser.getFullName(), request.getOrganisationName());
                    } else {
                        emailService.sendOrganiserApplicationApprovedEmail(
                                organiser.getEmail(), organiser.getFullName(), request.getOrganisationName());
                    }
                } else if (grantBadge) {
                    emailService.sendOrganiserVerifiedEmail(
                            organiser.getEmail(), organiser.getFullName());
                } else {
                    emailService.sendOrganiserBadgeNotGrantedEmail(
                            organiser.getEmail(), organiser.getFullName());
                }
            } catch (Exception e) {
                log.warn("Failed to send approval email: {}", e.getMessage());
            }
        } else {
            log.info("Admin {} rejected verification {} for organiser {} — reason: {}",
                    admin.getId(), requestId, request.getOrganiser().getId(), review.getRejectReason());

            try {
                User organiser = request.getOrganiser();
                if (request.isApplication()) {
                    emailService.sendOrganiserApplicationRejectedEmail(
                            organiser.getEmail(), organiser.getFullName(),
                            request.getOrganisationName(), review.getRejectReason());
                } else {
                    emailService.sendOrganiserVerificationRejectedEmail(
                            organiser.getEmail(), organiser.getFullName(), review.getRejectReason());
                }
            } catch (Exception e) {
                log.warn("Failed to send rejection email: {}", e.getMessage());
            }
        }

        return VerificationRequestResponse.fromEntity(requestRepository.save(request));
    }

    private static boolean isBlank(String s) {
        return s == null || s.isBlank();
    }

    private static String firstNonBlank(String... values) {
        for (String v : values) {
            if (v != null && !v.isBlank()) return v;
        }
        return null;
    }
}
