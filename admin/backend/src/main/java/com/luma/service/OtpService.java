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

@Service
@RequiredArgsConstructor
@Slf4j
public class OtpService {

    private final UserRepository userRepository;
    private static final int OTP_LENGTH = 6;
    private static final int OTP_EXPIRY_MINUTES = 5;
    private static final SecureRandom random = new SecureRandom();

    @Transactional
    public String generateOtp(String phone) {
        User user = userRepository.findByPhone(phone)
                .orElseThrow(() -> new BadRequestException("Phone number not found"));

        String otp = generateRandomOtp();

        user.setVerificationCode(otp);
        user.setVerificationCodeExpiry(LocalDateTime.now().plusMinutes(OTP_EXPIRY_MINUTES));
        userRepository.save(user);

        log.info("OTP generated for phone: {} (expires in {} minutes)", phone, OTP_EXPIRY_MINUTES);

        log.debug("OTP for {}: {}", phone, otp);

        return otp;
    }

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

        user.setPhoneVerified(true);
        user.setVerificationCode(null);
        user.setVerificationCodeExpiry(null);
        userRepository.save(user);

        log.info("Phone verified successfully: {}", phone);
        return true;
    }

    @Transactional
    public String sendOtpForRegistration(String phone) {
        if (userRepository.findByPhone(phone).isPresent()) {
            throw new BadRequestException("Phone number is already registered");
        }

        String otp = generateRandomOtp();

        log.info("OTP generated for new registration: {} (expires in {} minutes)", phone, OTP_EXPIRY_MINUTES);
        log.debug("OTP for new phone {}: {}", phone, otp);

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
