package com.luma.service;

import com.luma.entity.User;
import com.luma.exception.BadRequestException;
import com.luma.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.LocalDateTime;

/**
 * Service để quản lý OTP cho phone verification
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class OtpService {

    private final UserRepository userRepository;
    private static final int OTP_LENGTH = 6;
    private static final int OTP_EXPIRY_MINUTES = 5;
    private static final SecureRandom random = new SecureRandom();

    /**
     * Generate và lưu OTP cho user
     */
    @Transactional
    public String generateOtp(String phone) {
        User user = userRepository.findByPhone(phone)
                .orElseThrow(() -> new BadRequestException("Phone number not found"));

        String otp = generateRandomOtp();

        user.setVerificationCode(otp);
        user.setVerificationCodeExpiry(LocalDateTime.now().plusMinutes(OTP_EXPIRY_MINUTES));
        userRepository.save(user);

        log.info("OTP generated for phone: {} (expires in {} minutes)", phone, OTP_EXPIRY_MINUTES);

        // TODO: Integrate with SMS service (Twilio, AWS SNS, etc.)
        // For now, just log the OTP for development
        log.debug("OTP for {}: {}", phone, otp);

        return otp;
    }

    /**
     * Verify OTP
     */
    @Transactional
    public boolean verifyOtp(String phone, String otp) {
        User user = userRepository.findByPhone(phone)
                .orElseThrow(() -> new BadRequestException("Phone number not found"));

        if (user.getVerificationCode() == null) {
            throw new BadRequestException("No OTP was generated for this phone number");
        }

        if (user.getVerificationCodeExpiry() == null ||
            user.getVerificationCodeExpiry().isBefore(LocalDateTime.now())) {
            throw new BadRequestException("OTP has expired. Please request a new one.");
        }

        if (!user.getVerificationCode().equals(otp)) {
            throw new BadRequestException("Invalid OTP");
        }

        // OTP verified successfully - mark phone as verified
        user.setPhoneVerified(true);
        user.setVerificationCode(null);
        user.setVerificationCodeExpiry(null);
        userRepository.save(user);

        log.info("Phone verified successfully: {}", phone);
        return true;
    }

    /**
     * Send OTP để verify phone mới đăng ký
     */
    @Transactional
    public String sendOtpForRegistration(String phone) {
        // Check if phone already exists
        if (userRepository.findByPhone(phone).isPresent()) {
            throw new BadRequestException("Phone number is already registered");
        }

        // Generate OTP (lưu tạm vào cache hoặc session)
        String otp = generateRandomOtp();

        log.info("OTP generated for new registration: {} (expires in {} minutes)", phone, OTP_EXPIRY_MINUTES);
        log.debug("OTP for new phone {}: {}", phone, otp);

        // TODO: Send SMS via provider
        return otp;
    }

    private String generateRandomOtp() {
        StringBuilder otp = new StringBuilder();
        for (int i = 0; i < OTP_LENGTH; i++) {
            otp.append(random.nextInt(10));
        }
        return otp.toString();
    }
}
