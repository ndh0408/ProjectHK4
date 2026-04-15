package com.luma.repository;

import com.luma.entity.EmailCampaign;
import com.luma.entity.enums.EmailCampaignStatus;
import com.luma.entity.enums.EmailCampaignType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Repository
public interface EmailCampaignRepository extends JpaRepository<EmailCampaign, UUID> {

    Page<EmailCampaign> findAllByOrderByCreatedAtDesc(Pageable pageable);

    Page<EmailCampaign> findByStatus(EmailCampaignStatus status, Pageable pageable);

    Page<EmailCampaign> findByType(EmailCampaignType type, Pageable pageable);

    List<EmailCampaign> findByStatusAndScheduledAtBefore(EmailCampaignStatus status, LocalDateTime dateTime);

    @Query("SELECT c FROM EmailCampaign c WHERE c.status = :status AND c.scheduledAt <= :now")
    List<EmailCampaign> findScheduledCampaignsToSend(@Param("status") EmailCampaignStatus status, @Param("now") LocalDateTime now);

    @Query("SELECT COALESCE(SUM(c.sentCount), 0) FROM EmailCampaign c WHERE c.status = 'SENT'")
    long getTotalEmailsSent();

    @Query("SELECT COALESCE(SUM(c.openCount), 0) FROM EmailCampaign c WHERE c.status = 'SENT'")
    long getTotalEmailsOpened();

    @Query("SELECT COALESCE(SUM(c.clickCount), 0) FROM EmailCampaign c WHERE c.status = 'SENT'")
    long getTotalEmailsClicked();

    long countByStatus(EmailCampaignStatus status);
}
