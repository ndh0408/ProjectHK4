package com.luma.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.io.FileInputStream;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * Wires Firebase Admin SDK for FCM push notifications. The bean is only
 * registered when {@code fcm.enabled=true} AND a service-account JSON path is
 * provided (via {@code fcm.credentials-path} or {@code FCM_CREDENTIALS_PATH}).
 * Otherwise the app runs with push disabled and falls back to WebSocket/email.
 */
@Slf4j
@Configuration
@ConditionalOnProperty(name = "fcm.enabled", havingValue = "true")
public class FirebaseConfig {

    @Value("${fcm.credentials-path:}")
    private String credentialsPath;

    @Bean
    public FirebaseApp firebaseApp() throws Exception {
        if (!FirebaseApp.getApps().isEmpty()) {
            return FirebaseApp.getInstance();
        }

        if (credentialsPath == null || credentialsPath.isBlank()) {
            throw new IllegalStateException(
                    "fcm.enabled=true but fcm.credentials-path is empty. " +
                            "Set FCM_CREDENTIALS_PATH to your service-account.json");
        }

        Path path = Path.of(credentialsPath);
        if (!Files.exists(path)) {
            throw new IllegalStateException(
                    "FCM credentials file not found at: " + path.toAbsolutePath());
        }

        try (InputStream in = new FileInputStream(path.toFile())) {
            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(in))
                    .build();
            FirebaseApp app = FirebaseApp.initializeApp(options);
            log.info("Firebase Admin SDK initialised from {}", path.toAbsolutePath());
            return app;
        }
    }

    @Bean
    public FirebaseMessaging firebaseMessaging(FirebaseApp firebaseApp) {
        return FirebaseMessaging.getInstance(firebaseApp);
    }
}
