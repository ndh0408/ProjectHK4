package com.luma.config;

import io.github.bucket4j.Bandwidth;
import io.github.bucket4j.Bucket;
import io.github.bucket4j.Refill;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Configuration
@Component
public class RateLimitConfig {

    @Value("${rate-limit.enabled:true}")
    private boolean enabled;

    @Value("${rate-limit.login.requests-per-minute:10}")
    private int loginRequestsPerMinute;

    @Value("${rate-limit.register.requests-per-minute:5}")
    private int registerRequestsPerMinute;

    @Value("${rate-limit.api.requests-per-minute:100}")
    private int apiRequestsPerMinute;

    private final Map<String, Bucket> loginBuckets = new ConcurrentHashMap<>();
    private final Map<String, Bucket> registerBuckets = new ConcurrentHashMap<>();
    private final Map<String, Bucket> apiBuckets = new ConcurrentHashMap<>();

    public boolean isEnabled() {
        return enabled;
    }

    public Bucket getLoginBucket(String ipAddress) {
        return loginBuckets.computeIfAbsent(ipAddress, this::createLoginBucket);
    }

    public Bucket getRegisterBucket(String ipAddress) {
        return registerBuckets.computeIfAbsent(ipAddress, this::createRegisterBucket);
    }

    public Bucket getApiBucket(String ipAddress) {
        return apiBuckets.computeIfAbsent(ipAddress, this::createApiBucket);
    }

    private Bucket createLoginBucket(String key) {
        Bandwidth limit = Bandwidth.classic(
                loginRequestsPerMinute,
                Refill.greedy(loginRequestsPerMinute, Duration.ofMinutes(1))
        );
        return Bucket.builder().addLimit(limit).build();
    }

    private Bucket createRegisterBucket(String key) {
        Bandwidth limit = Bandwidth.classic(
                registerRequestsPerMinute,
                Refill.greedy(registerRequestsPerMinute, Duration.ofMinutes(1))
        );
        return Bucket.builder().addLimit(limit).build();
    }

    private Bucket createApiBucket(String key) {
        Bandwidth limit = Bandwidth.classic(
                apiRequestsPerMinute,
                Refill.greedy(apiRequestsPerMinute, Duration.ofMinutes(1))
        );
        return Bucket.builder().addLimit(limit).build();
    }

    public void cleanupOldBuckets() {
        if (loginBuckets.size() > 10000) {
            loginBuckets.clear();
        }
        if (registerBuckets.size() > 10000) {
            registerBuckets.clear();
        }
        if (apiBuckets.size() > 10000) {
            apiBuckets.clear();
        }
    }
}
