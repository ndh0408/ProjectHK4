package com.luma.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.luma.config.RateLimitConfig;
import io.github.bucket4j.Bucket;
import io.github.bucket4j.ConsumptionProbe;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.TimeUnit;

@Component
@Order(1)
@RequiredArgsConstructor
@Slf4j
public class RateLimitFilter extends OncePerRequestFilter {

    private final RateLimitConfig rateLimitConfig;
    private final ObjectMapper objectMapper;

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {

        if (!rateLimitConfig.isEnabled()) {
            filterChain.doFilter(request, response);
            return;
        }

        String path = request.getRequestURI();
        String method = request.getMethod();
        String clientIp = getClientIpAddress(request);

        Bucket bucket = selectBucket(path, method, clientIp);

        if (bucket == null) {
            filterChain.doFilter(request, response);
            return;
        }

        ConsumptionProbe probe = bucket.tryConsumeAndReturnRemaining(1);

        if (probe.isConsumed()) {
            response.addHeader("X-Rate-Limit-Remaining", String.valueOf(probe.getRemainingTokens()));
            filterChain.doFilter(request, response);
        } else {
            long waitForRefill = probe.getNanosToWaitForRefill() / 1_000_000_000;
            log.warn("Rate limit exceeded for IP: {} on path: {}", clientIp, path);

            response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
            response.addHeader("X-Rate-Limit-Retry-After-Seconds", String.valueOf(waitForRefill));

            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("status", HttpStatus.TOO_MANY_REQUESTS.value());
            errorResponse.put("error", "Too Many Requests");
            errorResponse.put("message", "Bạn đã gửi quá nhiều request. Vui lòng thử lại sau " + waitForRefill + " giây.");
            errorResponse.put("retryAfterSeconds", waitForRefill);

            response.getWriter().write(objectMapper.writeValueAsString(errorResponse));
        }
    }

    private Bucket selectBucket(String path, String method, String clientIp) {
        if (path.equals("/api/auth/login") && "POST".equals(method)) {
            return rateLimitConfig.getLoginBucket(clientIp);
        }

        if (path.equals("/api/auth/register") && "POST".equals(method)) {
            return rateLimitConfig.getRegisterBucket(clientIp);
        }

        if (path.equals("/api/auth/forgot-password") && "POST".equals(method)) {
            return rateLimitConfig.getRegisterBucket(clientIp);
        }

        if (path.equals("/api/auth/refresh-token") && "POST".equals(method)) {
            return rateLimitConfig.getLoginBucket(clientIp);
        }

        if (path.equals("/api/auth/google") && "POST".equals(method)) {
            return rateLimitConfig.getLoginBucket(clientIp);
        }

        if (path.startsWith("/api/") && !path.startsWith("/api/public/")) {
            return rateLimitConfig.getApiBucket(clientIp);
        }

        return null;
    }

    private String getClientIpAddress(HttpServletRequest request) {
        String xForwardedFor = request.getHeader("X-Forwarded-For");
        if (xForwardedFor != null && !xForwardedFor.isEmpty()) {
            return xForwardedFor.split(",")[0].trim();
        }

        String xRealIp = request.getHeader("X-Real-IP");
        if (xRealIp != null && !xRealIp.isEmpty()) {
            return xRealIp;
        }

        return request.getRemoteAddr();
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getRequestURI();
        return path.startsWith("/swagger") ||
               path.startsWith("/api-docs") ||
               path.startsWith("/actuator") ||
               path.startsWith("/favicon") ||
               path.equals("/");
    }
}
