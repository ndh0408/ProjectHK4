package com.luma.scheduler;

import com.luma.entity.Registration;
import com.luma.entity.enums.RegistrationStatus;
import com.luma.repository.RegistrationRepository;
import com.luma.service.RegistrationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Component
@RequiredArgsConstructor
@Slf4j
public class AttendanceReputationScheduler {

    private final RegistrationRepository registrationRepository;
    private final RegistrationService registrationService;

    /**
     * Mỗi giờ kiểm tra các sự kiện đã kết thúc quá 2 tiếng.
     * Nếu Registration đang là APPROVED/CONFIRMED mà chưa CHECKED_IN -> Chuyển thành NO_SHOW.
     */
    @Scheduled(fixedRate = 3600000) // 1 hour
    @Transactional
    public void trackNoShows() {
        log.info("AttendanceReputationScheduler: Running No-Show tracking task...");
        
        LocalDateTime threshold = LocalDateTime.now().minusHours(2);
        
        List<RegistrationStatus> activeStatuses = List.of(
                RegistrationStatus.APPROVED,
                RegistrationStatus.CONFIRMED
        );

        List<Registration> potentiallyNoShow = registrationRepository.findPotentiallyNoShow(threshold, activeStatuses);
        
        if (!potentiallyNoShow.isEmpty()) {
            log.info("AttendanceReputationScheduler: Found {} registrations that didn't check in. Converting to NO_SHOW.", potentiallyNoShow.size());
            for (Registration reg : potentiallyNoShow) {
                reg.setStatus(RegistrationStatus.NO_SHOW);
                registrationRepository.save(reg);
            }
        }
    }

    /**
     * Tự động hủy các đăng ký đã được duyệt (APPROVED) nhưng quá 48h user chưa bấm CONFIRM.
     * Chỉ áp dụng cho sự kiện FREE (dựa trên price = 0).
     */
    @Scheduled(fixedRate = 3600000) // 1 hour
    @Transactional
    public void expireUnconfirmedRegistrations() {
        log.info("AttendanceReputationScheduler: Running auto-expiry for unconfirmed approvals...");
        
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime expiryThreshold = LocalDateTime.now().minusHours(48);
        
        // Lấy các đơn APPROVED mà chưa CONFIRMED quá 48h
        List<Registration> expiredOnes = registrationRepository.findAll().stream()
                .filter(r -> r.getStatus() == RegistrationStatus.APPROVED)
                .filter(r -> r.getApprovedAt() != null && r.getApprovedAt().isBefore(expiryThreshold))
                .filter(r -> r.getCheckedInAt() == null)
                .filter(r -> r.getEvent() != null
                        && r.getEvent().getStartTime() != null
                        && r.getEvent().getStartTime().isAfter(now))
                .filter(r -> {
                    // Kiểm tra xem có phải event free không
                    return registrationService.getActualPrice(r).compareTo(java.math.BigDecimal.ZERO) == 0;
                })
                .toList();

        if (!expiredOnes.isEmpty()) {
            log.info("AttendanceReputationScheduler: Expiring {} unconfirmed registrations.", expiredOnes.size());
            for (Registration reg : expiredOnes) {
                // Tận dụng logic cancel sẵn có để nhả ticket/promote waitlist
                // Lưu ý: registerService.cancelRegistration yêu cầu User, 
                // ở đây scheduler làm nên ta set status thủ công và gọi promote
                reg.setStatus(RegistrationStatus.CANCELLED);
                registrationRepository.save(reg);
                registrationService.promoteFromWaitingList(reg.getEvent());
            }
        }
    }
}
