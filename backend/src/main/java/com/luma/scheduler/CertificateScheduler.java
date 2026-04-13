package com.luma.scheduler;

import com.luma.entity.Certificate;
import com.luma.entity.Event;
import com.luma.entity.Registration;
import com.luma.entity.enums.EventStatus;
import com.luma.entity.enums.RegistrationStatus;
import com.luma.repository.CertificateRepository;
import com.luma.repository.EventRepository;
import com.luma.repository.RegistrationRepository;
import com.luma.service.CertificateService;
import com.luma.service.EmailService;
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
public class CertificateScheduler {

    private final EventRepository eventRepository;
    private final RegistrationRepository registrationRepository;
    private final CertificateRepository certificateRepository;
    private final CertificateService certificateService;
    private final EmailService emailService;

    @Scheduled(fixedRate = 600000)
    @Transactional
    public void sendCertificatesForCompletedEvents() {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime oneDayAgo = now.minusHours(24);

        List<Event> completedEvents = eventRepository.findByStatusAndEndTimeBetween(
                EventStatus.COMPLETED, oneDayAgo, now);

        int certificatesSent = 0;

        for (Event event : completedEvents) {
            List<Registration> eligibleRegistrations = registrationRepository
                    .findByEventAndStatusAndCheckedInAtIsNotNull(event, RegistrationStatus.APPROVED);

            for (Registration registration : eligibleRegistrations) {
                if (certificateRepository.existsByRegistration(registration)) {
                    continue;
                }

                try {
                    var certificateResponse = certificateService.generateCertificate(registration.getId());

                    Certificate certificate = certificateRepository.findById(certificateResponse.getId())
                            .orElse(null);

                    if (certificate != null) {
                        emailService.sendCertificateEmail(
                                registration.getUser().getEmail(),
                                registration.getUser().getFullName(),
                                event.getTitle(),
                                event.getStartTime(),
                                event.getOrganiser().getFullName(),
                                event.getVenue(),
                                certificate.getCertificateCode(),
                                certificate.getCertificateUrl()
                        );

                        certificatesSent++;
                        log.debug("Certificate sent to {} for event '{}'",
                                registration.getUser().getEmail(), event.getTitle());
                    }
                } catch (Exception e) {
                    log.error("Failed to send certificate for registration {}: {}",
                            registration.getId(), e.getMessage());
                }
            }
        }

        if (certificatesSent > 0) {
            log.info("Automatically sent {} certificates for completed events", certificatesSent);
        }
    }
}
