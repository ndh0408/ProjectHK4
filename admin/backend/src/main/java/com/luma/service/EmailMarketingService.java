package com.luma.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.luma.dto.request.EmailCampaignRequest;
import com.luma.dto.response.EmailCampaignResponse;
import com.luma.dto.response.EmailMarketingStatsResponse;
import com.luma.entity.*;
import com.luma.entity.enums.EmailCampaignStatus;
import com.luma.entity.enums.UserRole;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.*;
import jakarta.mail.MessagingException;
import jakarta.mail.internet.MimeMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.scheduling.annotation.Async;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class EmailMarketingService {

    private final EmailCampaignRepository campaignRepository;
    private final EmailCampaignRecipientRepository recipientRepository;
    private final EmailUnsubscribeRepository unsubscribeRepository;
    private final UserRepository userRepository;
    private final EventRepository eventRepository;
    private final JavaMailSender mailSender;
    private final ObjectMapper objectMapper;

    @Value("${spring.mail.username}")
    private String fromEmail;

    @Value("${app.base-url}")
    private String baseUrl;

    @Transactional
    public EmailCampaignResponse createCampaign(User admin, EmailCampaignRequest request) {
        EmailCampaign campaign = EmailCampaign.builder()
                .name(request.getName())
                .subject(request.getSubject())
                .htmlContent(request.getHtmlContent())
                .plainTextContent(request.getPlainTextContent())
                .type(request.getType())
                .status(EmailCampaignStatus.DRAFT)
                .createdBy(admin)
                .build();

        if (request.getAudienceFilter() != null) {
            try {
                campaign.setAudienceFilter(objectMapper.writeValueAsString(request.getAudienceFilter()));
            } catch (JsonProcessingException e) {
                log.error("Failed to serialize audience filter: {}", e.getMessage());
            }
        }

        if (request.getRelatedEventId() != null) {
            Event event = eventRepository.findById(request.getRelatedEventId())
                    .orElseThrow(() -> new ResourceNotFoundException("Event not found"));
            campaign.setRelatedEvent(event);
        }

        if (request.getScheduledAt() != null) {
            if (request.getScheduledAt().isBefore(LocalDateTime.now())) {
                throw new BadRequestException("Scheduled time must be in the future");
            }
            campaign.setScheduledAt(request.getScheduledAt());
            campaign.setStatus(EmailCampaignStatus.SCHEDULED);
        }

        campaignRepository.save(campaign);

        buildRecipientList(campaign, request.getAudienceFilter());

        return EmailCampaignResponse.fromEntity(campaign);
    }

    @Transactional
    public EmailCampaignResponse updateCampaign(UUID campaignId, EmailCampaignRequest request) {
        EmailCampaign campaign = campaignRepository.findById(campaignId)
                .orElseThrow(() -> new ResourceNotFoundException("Campaign not found"));

        if (campaign.getStatus() != EmailCampaignStatus.DRAFT &&
            campaign.getStatus() != EmailCampaignStatus.SCHEDULED) {
            throw new BadRequestException("Cannot edit a campaign that is being sent or already sent");
        }

        campaign.setName(request.getName());
        campaign.setSubject(request.getSubject());
        campaign.setHtmlContent(request.getHtmlContent());
        campaign.setPlainTextContent(request.getPlainTextContent());
        campaign.setType(request.getType());

        if (request.getAudienceFilter() != null) {
            try {
                campaign.setAudienceFilter(objectMapper.writeValueAsString(request.getAudienceFilter()));
            } catch (JsonProcessingException e) {
                log.error("Failed to serialize audience filter: {}", e.getMessage());
            }
        }

        if (request.getScheduledAt() != null) {
            if (request.getScheduledAt().isBefore(LocalDateTime.now())) {
                throw new BadRequestException("Scheduled time must be in the future");
            }
            campaign.setScheduledAt(request.getScheduledAt());
            campaign.setStatus(EmailCampaignStatus.SCHEDULED);
        }

        recipientRepository.deleteByCampaignId(campaignId);
        buildRecipientList(campaign, request.getAudienceFilter());

        campaignRepository.save(campaign);
        return EmailCampaignResponse.fromEntity(campaign);
    }

    public EmailCampaignResponse getCampaign(UUID campaignId) {
        return campaignRepository.findById(campaignId)
                .map(EmailCampaignResponse::fromEntity)
                .orElseThrow(() -> new ResourceNotFoundException("Campaign not found"));
    }

    public Page<EmailCampaignResponse> getCampaigns(Pageable pageable) {
        return campaignRepository.findAllByOrderByCreatedAtDesc(pageable)
                .map(EmailCampaignResponse::fromEntity);
    }

    public Page<EmailCampaignResponse> getCampaignsByStatus(EmailCampaignStatus status, Pageable pageable) {
        return campaignRepository.findByStatus(status, pageable)
                .map(EmailCampaignResponse::fromEntity);
    }

    @Transactional
    public void deleteCampaign(UUID campaignId) {
        EmailCampaign campaign = campaignRepository.findById(campaignId)
                .orElseThrow(() -> new ResourceNotFoundException("Campaign not found"));

        if (campaign.getStatus() == EmailCampaignStatus.SENDING) {
            throw new BadRequestException("Cannot delete a campaign that is currently sending");
        }

        recipientRepository.deleteByCampaignId(campaignId);
        campaignRepository.delete(campaign);
    }

    @Transactional
    public EmailCampaignResponse sendCampaignNow(UUID campaignId) {
        EmailCampaign campaign = campaignRepository.findById(campaignId)
                .orElseThrow(() -> new ResourceNotFoundException("Campaign not found"));

        if (campaign.getStatus() != EmailCampaignStatus.DRAFT &&
            campaign.getStatus() != EmailCampaignStatus.SCHEDULED) {
            throw new BadRequestException("Campaign cannot be sent in current status");
        }

        campaign.setStatus(EmailCampaignStatus.SENDING);
        campaign.setScheduledAt(null);
        campaignRepository.save(campaign);

        sendCampaignEmails(campaign);

        return EmailCampaignResponse.fromEntity(campaign);
    }

    @Transactional
    public EmailCampaignResponse scheduleCampaign(UUID campaignId, LocalDateTime scheduledAt) {
        EmailCampaign campaign = campaignRepository.findById(campaignId)
                .orElseThrow(() -> new ResourceNotFoundException("Campaign not found"));

        if (scheduledAt.isBefore(LocalDateTime.now())) {
            throw new BadRequestException("Scheduled time must be in the future");
        }

        campaign.setScheduledAt(scheduledAt);
        campaign.setStatus(EmailCampaignStatus.SCHEDULED);
        campaignRepository.save(campaign);

        return EmailCampaignResponse.fromEntity(campaign);
    }

    @Transactional
    public EmailCampaignResponse cancelCampaign(UUID campaignId) {
        EmailCampaign campaign = campaignRepository.findById(campaignId)
                .orElseThrow(() -> new ResourceNotFoundException("Campaign not found"));

        if (campaign.getStatus() == EmailCampaignStatus.SENT) {
            throw new BadRequestException("Cannot cancel a campaign that has already been sent");
        }

        campaign.setStatus(EmailCampaignStatus.CANCELLED);
        campaignRepository.save(campaign);

        return EmailCampaignResponse.fromEntity(campaign);
    }

    @Scheduled(fixedRate = 60000)
    @Transactional
    public void processScheduledCampaigns() {
        List<EmailCampaign> scheduledCampaigns = campaignRepository.findScheduledCampaignsToSend(
                EmailCampaignStatus.SCHEDULED, LocalDateTime.now());

        for (EmailCampaign campaign : scheduledCampaigns) {
            campaign.setStatus(EmailCampaignStatus.SENDING);
            campaignRepository.save(campaign);
            sendCampaignEmails(campaign);
        }
    }

    @Async
    @Transactional
    public void sendCampaignEmails(EmailCampaign campaign) {
        List<EmailCampaignRecipient> recipients = recipientRepository.findByCampaignIdAndSentFalse(campaign.getId());

        int sentCount = 0;
        int bounceCount = 0;

        for (EmailCampaignRecipient recipient : recipients) {
            if (unsubscribeRepository.existsByEmail(recipient.getEmail())) {
                continue;
            }

            try {
                sendEmail(recipient, campaign);
                recipient.setSent(true);
                recipient.setSentAt(LocalDateTime.now());
                sentCount++;
            } catch (Exception e) {
                log.error("Failed to send email to {}: {}", recipient.getEmail(), e.getMessage());
                recipient.setBounced(true);
                recipient.setBounceReason(e.getMessage());
                bounceCount++;
            }

            recipientRepository.save(recipient);
        }

        campaign.setSentCount(campaign.getSentCount() + sentCount);
        campaign.setBounceCount(campaign.getBounceCount() + bounceCount);
        campaign.setStatus(EmailCampaignStatus.SENT);
        campaign.setSentAt(LocalDateTime.now());
        campaignRepository.save(campaign);

        log.info("Campaign '{}' sent: {} emails delivered, {} bounced", campaign.getName(), sentCount, bounceCount);
    }

    private void sendEmail(EmailCampaignRecipient recipient, EmailCampaign campaign) throws MessagingException {
        MimeMessage message = mailSender.createMimeMessage();
        MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");

        helper.setFrom(fromEmail);
        helper.setTo(recipient.getEmail());
        helper.setSubject(campaign.getSubject());

        String html = addTrackingToHtml(campaign.getHtmlContent(), recipient.getId(), campaign.getId());
        helper.setText(campaign.getPlainTextContent() != null ? campaign.getPlainTextContent() : "", html);

        mailSender.send(message);
    }

    private String addTrackingToHtml(String html, UUID recipientId, UUID campaignId) {
        String trackingPixel = String.format(
                "<img src=\"%s/api/email/track/open/%s\" width=\"1\" height=\"1\" style=\"display:none\" />",
                baseUrl, recipientId);

        String unsubscribeLink = String.format(
                "<p style=\"margin-top:20px;font-size:12px;color:#888;\">If you no longer wish to receive these emails, " +
                "<a href=\"%s/api/email/unsubscribe/%s\">unsubscribe here</a>.</p>",
                baseUrl, recipientId);

        if (html.contains("</body>")) {
            html = html.replace("</body>", trackingPixel + unsubscribeLink + "</body>");
        } else {
            html = html + trackingPixel + unsubscribeLink;
        }

        return html;
    }

    @Transactional
    public void trackOpen(UUID recipientId) {
        recipientRepository.findById(recipientId).ifPresent(recipient -> {
            if (!recipient.getOpened()) {
                recipient.setOpened(true);
                recipient.setOpenedAt(LocalDateTime.now());
                recipientRepository.save(recipient);

                EmailCampaign campaign = recipient.getCampaign();
                campaign.setOpenCount(campaign.getOpenCount() + 1);
                campaignRepository.save(campaign);
            }
        });
    }

    @Transactional
    public void trackClick(UUID recipientId) {
        recipientRepository.findById(recipientId).ifPresent(recipient -> {
            if (!recipient.getClicked()) {
                recipient.setClicked(true);
                recipient.setClickedAt(LocalDateTime.now());
                recipientRepository.save(recipient);

                EmailCampaign campaign = recipient.getCampaign();
                campaign.setClickCount(campaign.getClickCount() + 1);
                campaignRepository.save(campaign);
            }
        });
    }

    @Transactional
    public void handleUnsubscribe(UUID recipientId, String reason) {
        recipientRepository.findById(recipientId).ifPresent(recipient -> {
            recipient.setUnsubscribed(true);
            recipientRepository.save(recipient);

            EmailCampaign campaign = recipient.getCampaign();
            campaign.setUnsubscribeCount(campaign.getUnsubscribeCount() + 1);
            campaignRepository.save(campaign);

            if (!unsubscribeRepository.existsByEmail(recipient.getEmail())) {
                EmailUnsubscribe unsubscribe = EmailUnsubscribe.builder()
                        .email(recipient.getEmail())
                        .user(recipient.getUser())
                        .reason(reason)
                        .fromCampaign(campaign)
                        .build();
                unsubscribeRepository.save(unsubscribe);
            }
        });
    }

    public EmailMarketingStatsResponse getMarketingStats() {
        long totalSent = campaignRepository.getTotalEmailsSent();
        long totalOpened = campaignRepository.getTotalEmailsOpened();
        long totalClicked = campaignRepository.getTotalEmailsClicked();

        double avgOpenRate = totalSent > 0 ? (totalOpened * 100.0 / totalSent) : 0;
        double avgClickRate = totalOpened > 0 ? (totalClicked * 100.0 / totalOpened) : 0;

        return EmailMarketingStatsResponse.builder()
                .totalCampaigns(campaignRepository.count())
                .draftCampaigns(campaignRepository.countByStatus(EmailCampaignStatus.DRAFT))
                .sentCampaigns(campaignRepository.countByStatus(EmailCampaignStatus.SENT))
                .scheduledCampaigns(campaignRepository.countByStatus(EmailCampaignStatus.SCHEDULED))
                .totalEmailsSent(totalSent)
                .totalEmailsOpened(totalOpened)
                .totalEmailsClicked(totalClicked)
                .totalUnsubscribes(unsubscribeRepository.count())
                .averageOpenRate(avgOpenRate)
                .averageClickRate(avgClickRate)
                .build();
    }

    private void buildRecipientList(EmailCampaign campaign, EmailCampaignRequest.AudienceFilter filter) {
        List<User> targetUsers;

        if (filter == null) {
            targetUsers = userRepository.findAll().stream()
                    .filter(User::isEmailNotificationsEnabled)
                    .collect(Collectors.toList());
        } else {
            targetUsers = userRepository.findAll().stream()
                    .filter(User::isEmailNotificationsEnabled)
                    .filter(user -> {
                        if (filter.getUserRole() != null) {
                            return user.getRole().name().equals(filter.getUserRole());
                        }
                        return true;
                    })
                    .collect(Collectors.toList());
        }

        Set<String> unsubscribedEmails = unsubscribeRepository.findAll().stream()
                .map(EmailUnsubscribe::getEmail)
                .collect(Collectors.toSet());

        List<EmailCampaignRecipient> recipients = targetUsers.stream()
                .filter(user -> user.getEmail() != null && !unsubscribedEmails.contains(user.getEmail()))
                .map(user -> EmailCampaignRecipient.builder()
                        .campaign(campaign)
                        .user(user)
                        .email(user.getEmail())
                        .build())
                .collect(Collectors.toList());

        recipientRepository.saveAll(recipients);
        campaign.setTotalRecipients(recipients.size());
        campaignRepository.save(campaign);
    }
}
