package com.luma.service;

import com.luma.dto.request.DeviceTokenRequest;
import com.luma.entity.DeviceToken;
import com.luma.entity.User;
import com.luma.entity.enums.DevicePlatform;
import com.luma.repository.DeviceTokenRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class DeviceTokenService {

    private final DeviceTokenRepository deviceTokenRepository;

    /**
     * Register or refresh an FCM token for the given user.
     *
     * Same token + same user → just bump {@code lastUsedAt}.
     * Same token + different user (device changed hands) → reassign to the new
     * user. Otherwise insert a new row. Tokens are globally unique so this
     * guarantees no two users silently receive the same device's pushes.
     */
    @Transactional
    public void upsert(User user, DeviceTokenRequest req) {
        String token = req.getToken().trim();
        Optional<DeviceToken> existing = deviceTokenRepository.findByToken(token);

        DeviceToken entity = existing.orElseGet(() -> DeviceToken.builder()
                .token(token)
                .build());

        entity.setUser(user);
        entity.setPlatform(req.getPlatform() != null ? req.getPlatform() : DevicePlatform.ANDROID);
        entity.setDeviceModel(req.getDeviceModel());
        entity.setAppVersion(req.getAppVersion());
        entity.setLastUsedAt(LocalDateTime.now());

        deviceTokenRepository.save(entity);
        log.debug("Upserted FCM token for user {} on platform {}", user.getId(), entity.getPlatform());
    }

    @Transactional
    public void unregister(UUID userId, String token) {
        if (token == null || token.isBlank()) return;
        deviceTokenRepository.deleteByUserIdAndToken(userId, token.trim());
    }
}
