package com.luma.service;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import com.luma.dto.request.GoogleAuthRequest;
import com.luma.dto.request.LoginRequest;
import com.luma.dto.request.RegisterRequest;
import com.luma.dto.response.AuthResponse;
import com.luma.dto.response.UserResponse;
import com.luma.entity.RefreshToken;
import com.luma.entity.User;
import com.luma.entity.enums.UserStatus;
import com.luma.exception.BadRequestException;
import com.luma.exception.UnauthorizedException;
import com.luma.repository.RefreshTokenRepository;
import com.luma.repository.UserRepository;
import com.luma.security.JwtService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Collections;
import java.util.Optional;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final AuthenticationManager authenticationManager;
    private final UserService userService;

    @Value("${jwt.expiration}")
    private long jwtExpiration;

    @Value("${jwt.refresh-expiration}")
    private long refreshExpiration;

    @Value("${google.client-id}")
    private String googleClientId;

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        if (request.getEmail() == null && request.getPhone() == null) {
            throw new BadRequestException("Email or phone number is required");
        }

        User user = userService.createUser(request);
        return generateAuthResponse(user);
    }

    @Transactional
    public AuthResponse login(LoginRequest request) {
        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new UnauthorizedException("Invalid email or password"));

        if (!passwordEncoder.matches(request.getPassword(), user.getPassword())) {
            throw new UnauthorizedException("Invalid email/phone or password");
        }

        if (user.getStatus() != UserStatus.ACTIVE) {
            throw new UnauthorizedException("Your account has been locked. Please contact administrator.");
        }

        userService.updateLastLogin(user.getId());
        return generateAuthResponse(user);
    }

    @Transactional
    public AuthResponse refreshToken(String refreshToken) {
        RefreshToken token = refreshTokenRepository.findByToken(refreshToken)
                .orElseThrow(() -> new UnauthorizedException("Invalid refresh token"));

        if (token.isExpired()) {
            refreshTokenRepository.delete(token);
            throw new UnauthorizedException("Refresh token has expired");
        }

        User user = token.getUser();

        if (user.getStatus() != UserStatus.ACTIVE) {
            refreshTokenRepository.delete(token);
            throw new UnauthorizedException("Your account has been locked. Please contact administrator.");
        }

        return generateAuthResponse(user);
    }

    @Transactional
    public void logout(User user) {
        refreshTokenRepository.deleteByUser(user);
    }

    @Transactional
    public AuthResponse googleAuth(GoogleAuthRequest request) {
        String email;
        String fullName;
        String avatarUrl;

        if (request.getIdToken() != null && !request.getIdToken().isEmpty()) {
            try {
                GoogleIdTokenVerifier verifier = new GoogleIdTokenVerifier.Builder(
                        new NetHttpTransport(), GsonFactory.getDefaultInstance())
                        .setAudience(Collections.singletonList(googleClientId))
                        .build();

                GoogleIdToken idToken = verifier.verify(request.getIdToken());
                if (idToken == null) {
                    throw new UnauthorizedException("Invalid Google ID token");
                }

                GoogleIdToken.Payload payload = idToken.getPayload();
                email = payload.getEmail();
                fullName = (String) payload.get("name");
                avatarUrl = (String) payload.get("picture");
            } catch (UnauthorizedException e) {
                throw e;
            } catch (Exception e) {
                log.error("Google ID token verification failed", e);
                throw new UnauthorizedException("Google authentication failed: " + e.getMessage());
            }
        } else if (request.getAccessToken() != null && !request.getAccessToken().isEmpty()
                && request.getEmail() != null && !request.getEmail().isEmpty()) {
            email = request.getEmail();
            fullName = request.getFullName();
            avatarUrl = request.getAvatarUrl();
            log.info("Google auth via accessToken for email: {}", email);
        } else {
            throw new BadRequestException("Either idToken or (accessToken + email) is required");
        }

        if (email == null || email.isEmpty()) {
            throw new BadRequestException("Email not provided by Google");
        }

        try {
            Optional<User> existingUser = userRepository.findByEmail(email);
            User user;

            if (existingUser.isPresent()) {
                user = existingUser.get();
                if (user.getStatus() != UserStatus.ACTIVE) {
                    throw new UnauthorizedException("Your account has been locked. Please contact administrator.");
                }
                if (user.getAvatarUrl() == null && avatarUrl != null) {
                    user.setAvatarUrl(avatarUrl);
                    userRepository.save(user);
                }
                userService.updateLastLogin(user.getId());
            } else {
                user = User.builder()
                        .email(email)
                        .fullName(fullName != null ? fullName : email.split("@")[0])
                        .avatarUrl(avatarUrl)
                        .emailVerified(true)
                        .password(passwordEncoder.encode(UUID.randomUUID().toString()))
                        .build();
                user = userRepository.save(user);
                log.info("New user created via Google Sign-In: {}", email);
            }

            return generateAuthResponse(user);
        } catch (UnauthorizedException | BadRequestException e) {
            throw e;
        } catch (Exception e) {
            log.error("Google authentication failed", e);
            throw new UnauthorizedException("Google authentication failed: " + e.getMessage());
        }
    }

    private AuthResponse generateAuthResponse(User user) {
        String accessToken = jwtService.generateToken(user);
        String refreshToken = createRefreshToken(user);

        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .tokenType("Bearer")
                .expiresIn(jwtExpiration)
                .user(UserResponse.fromEntity(user))
                .build();
    }

    private String createRefreshToken(User user) {
        refreshTokenRepository.deleteByUser(user);

        RefreshToken refreshToken = RefreshToken.builder()
                .user(user)
                .token(UUID.randomUUID().toString())
                .expiryDate(Instant.now().plusMillis(refreshExpiration))
                .build();

        return refreshTokenRepository.save(refreshToken).getToken();
    }
}
