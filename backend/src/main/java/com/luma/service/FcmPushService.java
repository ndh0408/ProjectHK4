package com.luma.service;

import com.google.firebase.messaging.*;
import com.luma.entity.DeviceToken;
import com.luma.entity.User;
import com.luma.entity.enums.NotificationType;
import com.luma.repository.DeviceTokenRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Fans out a notification to every FCM device token a user has registered.
 * The {@link FirebaseMessaging} bean is optional — when {@code fcm.enabled=false}
 * the field stays null and every call becomes a silent no-op so the app can
 * run in dev without Firebase credentials.
 *
 * Invalid / unregistered tokens returned by FCM are purged from the DB so we
 * don't keep sending to dead devices.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class FcmPushService {

    private final DeviceTokenRepository deviceTokenRepository;

    @Autowired(required = false)
    private FirebaseMessaging firebaseMessaging;

    public boolean isEnabled() {
        return firebaseMessaging != null;
    }

    public void sendToUser(User user, String title, String body, NotificationType type,
                           UUID referenceId, String referenceType) {
        if (!isEnabled() || user == null) return;

        List<DeviceToken> tokens = deviceTokenRepository.findByUser(user);
        if (tokens.isEmpty()) return;

        List<String> tokenStrings = tokens.stream().map(DeviceToken::getToken).toList();

        Map<String, String> data = new HashMap<>();
        if (type != null) data.put("type", type.name());
        if (referenceId != null) data.put("referenceId", referenceId.toString());
        if (referenceType != null) data.put("referenceType", referenceType);

        MulticastMessage message = MulticastMessage.builder()
                .addAllTokens(tokenStrings)
                .setNotification(Notification.builder()
                        .setTitle(title)
                        .setBody(body)
                        .build())
                .putAllData(data)
                .setAndroidConfig(AndroidConfig.builder()
                        .setPriority(AndroidConfig.Priority.HIGH)
                        .setNotification(AndroidNotification.builder()
                                .setChannelId("luma_default")
                                .setDefaultSound(true)
                                .build())
                        .build())
                .setApnsConfig(ApnsConfig.builder()
                        .setAps(Aps.builder().setSound("default").build())
                        .build())
                .build();

        try {
            BatchResponse response = firebaseMessaging.sendEachForMulticast(message);
            if (response.getFailureCount() > 0) {
                pruneDeadTokens(response, tokenStrings);
            }
            log.debug("FCM push to user {}: {} succeeded, {} failed",
                    user.getId(), response.getSuccessCount(), response.getFailureCount());
        } catch (FirebaseMessagingException e) {
            log.warn("FCM multicast failed for user {}: {}", user.getId(), e.getMessage());
        }
    }

    private void pruneDeadTokens(BatchResponse response, List<String> tokens) {
        List<String> dead = new ArrayList<>();
        List<SendResponse> responses = response.getResponses();
        for (int i = 0; i < responses.size(); i++) {
            SendResponse r = responses.get(i);
            if (r.isSuccessful()) continue;
            MessagingErrorCode code = r.getException() != null
                    ? r.getException().getMessagingErrorCode() : null;
            if (code == MessagingErrorCode.UNREGISTERED
                    || code == MessagingErrorCode.INVALID_ARGUMENT) {
                dead.add(tokens.get(i));
            }
        }
        if (!dead.isEmpty()) {
            deviceTokenRepository.deleteByTokenIn(dead);
            log.info("Pruned {} dead FCM tokens", dead.size());
        }
    }
}
