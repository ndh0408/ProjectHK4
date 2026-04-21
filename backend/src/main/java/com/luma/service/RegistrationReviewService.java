package com.luma.service;

import com.luma.dto.response.RegistrationResponse;
import com.luma.entity.Registration;
import com.luma.entity.User;
import com.luma.entity.enums.RegistrationStatus;
import com.luma.repository.RegistrationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class RegistrationReviewService {

    private final RegistrationRepository registrationRepository;

    public RegistrationResponse enrichWithReviewData(RegistrationResponse response, Registration reg) {
        User user = reg.getUser();
        
        int score = 0;
        List<String> reasons = new ArrayList<>();
        List<String> warnings = new ArrayList<>();

        // 1. Trust & Verification (30 pts max)
        if (user.isEmailVerified() && user.isPhoneVerified()) {
            score += 25;
            reasons.add("Verified đầy đủ (Email & Phone)");
        } else if (user.isEmailVerified()) {
            score += 15;
            reasons.add("Email đã verified");
        } else {
            warnings.add("Chưa verify thông tin liên lạc");
        }
        
        if (user.getLinkedinUrl() != null && !user.getLinkedinUrl().isEmpty()) {
            score += 5;
            reasons.add("Có LinkedIn profile");
        }

        // 2. History & Reputation (40 pts max)
        long attended = registrationRepository.countByUserAndStatus(user, RegistrationStatus.CHECKED_IN);
        // Also consider CONFIRMED but past event as potential NO_SHOW if logic allows, 
        // but let's stick to explicit NO_SHOW status for now.
        long noShows = registrationRepository.countByUserAndStatus(user, RegistrationStatus.NO_SHOW);
        
        score += (int) Math.min(attended * 10, 40);
        if (attended > 0) reasons.add("Đã từng tham gia " + attended + " sự kiện");
        
        if (noShows > 0) {
            score -= (int) (noShows * 30);
            warnings.add("Lịch sử NO-SHOW: " + noShows + " lần");
        }

        // 3. Profile Quality (15 pts max)
        if (user.getJobTitle() != null && !user.getJobTitle().isEmpty() && 
            user.getCompany() != null && !user.getCompany().isEmpty()) {
            score += 15;
            reasons.add("Hồ sơ nghề nghiệp đầy đủ (" + user.getJobTitle() + " @ " + user.getCompany() + ")");
        } else if (user.getJobTitle() != null && !user.getJobTitle().isEmpty()) {
            score += 5;
            reasons.add("Có thông tin chức vụ");
        } else {
            warnings.add("Hồ sơ nghề nghiệp trống");
        }

        // 4. Intent Signal (15 pts max)
        // Check if any answer is substantial
        boolean hasDetailedAnswers = reg.getAnswers() != null && reg.getAnswers().stream()
                .anyMatch(a -> a.getAnswerText() != null && a.getAnswerText().trim().length() > 30);
        if (hasDetailedAnswers) {
            score += 15;
            reasons.add("Mục tiêu tham gia rõ ràng/có đầu tư");
        } else {
            warnings.add("Trả lời form sơ sài");
        }

        response.setTotalScore(Math.max(0, Math.min(100, score)));
        response.setScoreReasons(reasons);
        response.setWarningFlags(warnings);
        response.setPastEventsAttended((int) attended);
        response.setPastNoShows((int) noShows);
        
        return response;
    }
}
