package com.luma.controller;

import com.luma.entity.Certificate;
import com.luma.entity.Registration;
import com.luma.repository.CertificateRepository;
import com.luma.repository.RegistrationRepository;
import com.luma.service.CertificateService;
import com.luma.service.EmailService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/webhooks/dev-certificate")
@RequiredArgsConstructor
@Slf4j
public class DevCertificateTestController {

    private final RegistrationRepository registrationRepository;
    private final CertificateRepository certificateRepository;
    private final CertificateService certificateService;
    private final EmailService emailService;

    @Value("${server.port:8080}")
    private String serverPort;

    @PostMapping("/test-send")
    @Transactional
    public Map<String, Object> testSend(
            @RequestParam UUID registrationId,
            @RequestParam String email,
            @RequestParam(defaultValue = "false") boolean regenerate) {

        Registration registration = registrationRepository.findById(registrationId)
                .orElseThrow(() -> new RuntimeException("Registration not found: " + registrationId));

        if (regenerate) {
            certificateRepository.findByRegistration(registration).ifPresent(existing -> {
                log.info("DEV: regenerating cert, deleting old {}", existing.getCertificateCode());
                certificateRepository.delete(existing);
                certificateRepository.flush();
            });
        }

        Certificate certificate = certificateRepository.findByRegistration(registration)
                .orElseGet(() -> {
                    var resp = certificateService.generateCertificate(registrationId);
                    return certificateRepository.findById(resp.getId()).orElseThrow();
                });

        var event = registration.getEvent();
        var attendee = registration.getUser();

        String backendPdfUrl = "http://localhost:" + serverPort
                + "/api/certificates/" + certificate.getCertificateCode() + "/pdf?download=true";

        emailService.sendCertificateEmail(
                email,
                attendee.getFullName(),
                event.getTitle(),
                event.getStartTime(),
                event.getOrganiser().getFullName(),
                event.getVenue(),
                certificate.getCertificateCode(),
                backendPdfUrl
        );

        log.info("DEV: certificate '{}' dispatched to {} (link={})",
                certificate.getCertificateCode(), email, backendPdfUrl);

        return Map.of(
                "ok", true,
                "sentTo", email,
                "certificateCode", certificate.getCertificateCode(),
                "downloadUrl", backendPdfUrl,
                "cloudinaryUrl", certificate.getCertificateUrl(),
                "eventTitle", event.getTitle()
        );
    }

}
