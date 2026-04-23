package com.luma.service;

import com.luma.dto.response.QrLoginChallengeResponse;
import com.luma.dto.response.QrLoginStatusResponse;
import com.luma.entity.User;
import com.luma.entity.enums.QrLoginChallengeStatus;
import com.luma.exception.BadRequestException;
import com.luma.exception.UnauthorizedException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

@Service
@Slf4j
@RequiredArgsConstructor
public class QrLoginService {

    private static final Duration CHALLENGE_TTL = Duration.ofMinutes(3);
    private static final Duration APPROVED_TTL = Duration.ofMinutes(2);
    private static final Duration RETENTION_AFTER_FINAL_STATE = Duration.ofMinutes(5);
    private static final int MAX_ACTIVE_CHALLENGES = 10_000;
    private static final SecureRandom RANDOM = new SecureRandom();

    private final Map<UUID, ChallengeState> challenges = new ConcurrentHashMap<>();

    public synchronized QrLoginChallengeResponse createChallenge() {
        cleanupChallenges();

        if (challenges.size() >= MAX_ACTIVE_CHALLENGES) {
            throw new BadRequestException("Too many active QR login challenges. Please try again shortly.");
        }

        UUID challengeId = UUID.randomUUID();
        String approvalCode = randomToken(24);
        String pollingToken = randomToken(32);
        Instant expiresAt = Instant.now().plus(CHALLENGE_TTL);

        challenges.put(
                challengeId,
                ChallengeState.builder()
                        .challengeId(challengeId)
                        .approvalCode(approvalCode)
                        .pollingToken(pollingToken)
                        .status(QrLoginChallengeStatus.PENDING)
                        .expiresAt(expiresAt)
                        .build()
        );

        return QrLoginChallengeResponse.builder()
                .challengeId(challengeId)
                .qrData(buildQrData(challengeId, approvalCode))
                .pollingToken(pollingToken)
                .expiresAt(expiresAt)
                .expiresInSeconds(CHALLENGE_TTL.toSeconds())
                .build();
    }

    public synchronized QrLoginStatusResponse getStatus(UUID challengeId, String pollingToken) {
        ChallengeState challenge = requireChallenge(challengeId);
        validatePollingToken(challenge, pollingToken);
        expireIfNeeded(challenge);
        return toStatusResponse(challenge);
    }

    public synchronized UUID approveChallenge(UUID challengeId, String approvalCode, User approver) {
        ChallengeState challenge = requireChallenge(challengeId);
        expireIfNeeded(challenge);

        if (challenge.getStatus() == QrLoginChallengeStatus.EXPIRED) {
            throw new BadRequestException("This QR login request has expired. Please refresh the QR code on web.");
        }
        if (challenge.getStatus() == QrLoginChallengeStatus.CONSUMED) {
            throw new BadRequestException("This QR login request has already been used.");
        }
        if (challenge.getStatus() == QrLoginChallengeStatus.APPROVED) {
            throw new BadRequestException("This QR login request has already been approved.");
        }
        if (!constantTimeEquals(challenge.getApprovalCode(), approvalCode)) {
            throw new UnauthorizedException("Invalid QR login approval code.");
        }

        challenge.setStatus(QrLoginChallengeStatus.APPROVED);
        challenge.setApprovedAt(Instant.now());
        challenge.setApprovedByUserId(approver.getId());
        challenge.setApprovedByName(
                approver.getFullName() != null && !approver.getFullName().isBlank()
                        ? approver.getFullName()
                        : approver.getEmail()
        );
        log.info("QR login challenge {} approved by user {}", challengeId, approver.getId());
        return approver.getId();
    }

    public synchronized UUID consumeApprovedChallenge(UUID challengeId, String pollingToken) {
        ChallengeState challenge = requireChallenge(challengeId);
        validatePollingToken(challenge, pollingToken);
        expireIfNeeded(challenge);

        if (challenge.getStatus() == QrLoginChallengeStatus.EXPIRED) {
            throw new BadRequestException("This QR login request has expired. Please generate a new QR code.");
        }
        if (challenge.getStatus() == QrLoginChallengeStatus.PENDING) {
            throw new BadRequestException("This QR login request has not been approved yet.");
        }
        if (challenge.getStatus() == QrLoginChallengeStatus.CONSUMED) {
            throw new BadRequestException("This QR login request has already been used.");
        }
        if (challenge.getApprovedByUserId() == null) {
            throw new BadRequestException("This QR login request is missing its approved user.");
        }

        challenge.setStatus(QrLoginChallengeStatus.CONSUMED);
        challenge.setConsumedAt(Instant.now());
        log.info("QR login challenge {} consumed for user {}", challengeId, challenge.getApprovedByUserId());
        return challenge.getApprovedByUserId();
    }

    @Scheduled(fixedDelay = 60_000L, initialDelay = 60_000L)
    public synchronized void cleanupChallenges() {
        Instant now = Instant.now();
        List<UUID> toRemove = new ArrayList<>();

        for (Map.Entry<UUID, ChallengeState> entry : challenges.entrySet()) {
            ChallengeState state = entry.getValue();
            expireIfNeeded(state);

            Instant terminalTimestamp = state.getConsumedAt();
            if (terminalTimestamp == null && state.getStatus() == QrLoginChallengeStatus.EXPIRED) {
                terminalTimestamp = state.getExpiresAt();
            }

            if (terminalTimestamp != null &&
                    terminalTimestamp.plus(RETENTION_AFTER_FINAL_STATE).isBefore(now)) {
                toRemove.add(entry.getKey());
            }
        }

        for (UUID challengeId : toRemove) {
            challenges.remove(challengeId);
        }

        if (!toRemove.isEmpty()) {
            log.debug("QR login cleanup removed {} stale challenges (remaining: {})",
                    toRemove.size(), challenges.size());
        }
    }

    private ChallengeState requireChallenge(UUID challengeId) {
        ChallengeState challenge = challenges.get(challengeId);
        if (challenge == null) {
            throw new BadRequestException("QR login request not found or already cleaned up.");
        }
        return challenge;
    }

    private void validatePollingToken(ChallengeState challenge, String pollingToken) {
        if (pollingToken == null || pollingToken.isBlank() ||
                !constantTimeEquals(challenge.getPollingToken(), pollingToken)) {
            throw new UnauthorizedException("Invalid QR login polling token.");
        }
    }

    private void expireIfNeeded(ChallengeState challenge) {
        Instant now = Instant.now();
        if (challenge.getStatus() == QrLoginChallengeStatus.PENDING &&
                now.isAfter(challenge.getExpiresAt())) {
            challenge.setStatus(QrLoginChallengeStatus.EXPIRED);
            return;
        }
        if (challenge.getStatus() == QrLoginChallengeStatus.APPROVED &&
                challenge.getApprovedAt() != null &&
                now.isAfter(challenge.getApprovedAt().plus(APPROVED_TTL))) {
            challenge.setStatus(QrLoginChallengeStatus.EXPIRED);
        }
    }

    private QrLoginStatusResponse toStatusResponse(ChallengeState challenge) {
        long expiresInSeconds = Math.max(0, Duration.between(Instant.now(), challenge.getExpiresAt()).getSeconds());
        return QrLoginStatusResponse.builder()
                .challengeId(challenge.getChallengeId())
                .status(challenge.getStatus())
                .expiresAt(challenge.getExpiresAt())
                .expiresInSeconds(expiresInSeconds)
                .approvedByName(challenge.getApprovedByName())
                .approvedAt(challenge.getApprovedAt())
                .build();
    }

    private String buildQrData(UUID challengeId, String approvalCode) {
        return "luma://qr-login?challengeId=" + challengeId + "&approvalCode=" + approvalCode;
    }

    private String randomToken(int bytes) {
        byte[] raw = new byte[bytes];
        RANDOM.nextBytes(raw);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(raw);
    }

    private static boolean constantTimeEquals(String a, String b) {
        if (a == null || b == null) {
            return false;
        }
        byte[] aBytes = a.getBytes(java.nio.charset.StandardCharsets.UTF_8);
        byte[] bBytes = b.getBytes(java.nio.charset.StandardCharsets.UTF_8);
        return java.security.MessageDigest.isEqual(aBytes, bBytes);
    }

    @lombok.Data
    @lombok.Builder
    private static class ChallengeState {
        private UUID challengeId;
        private String approvalCode;
        private String pollingToken;
        private QrLoginChallengeStatus status;
        private Instant expiresAt;
        private UUID approvedByUserId;
        private String approvedByName;
        private Instant approvedAt;
        private Instant consumedAt;
    }
}
