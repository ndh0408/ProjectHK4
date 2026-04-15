package com.luma.repository;

import com.luma.entity.EmailCampaignRecipient;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface EmailCampaignRecipientRepository extends JpaRepository<EmailCampaignRecipient, UUID> {

    Page<EmailCampaignRecipient> findByCampaignId(UUID campaignId, Pageable pageable);

    List<EmailCampaignRecipient> findByCampaignIdAndSentFalse(UUID campaignId);

    Optional<EmailCampaignRecipient> findByCampaignIdAndUserId(UUID campaignId, UUID userId);

    Optional<EmailCampaignRecipient> findByCampaignIdAndEmail(UUID campaignId, String email);

    long countByCampaignId(UUID campaignId);

    long countByCampaignIdAndSentTrue(UUID campaignId);

    long countByCampaignIdAndOpenedTrue(UUID campaignId);

    long countByCampaignIdAndClickedTrue(UUID campaignId);

    long countByCampaignIdAndBouncedTrue(UUID campaignId);

    @Modifying
    @Query("UPDATE EmailCampaignRecipient r SET r.opened = true, r.openedAt = :openedAt WHERE r.id = :id AND r.opened = false")
    void markAsOpened(@Param("id") UUID id, @Param("openedAt") LocalDateTime openedAt);

    @Modifying
    @Query("UPDATE EmailCampaignRecipient r SET r.clicked = true, r.clickedAt = :clickedAt WHERE r.id = :id AND r.clicked = false")
    void markAsClicked(@Param("id") UUID id, @Param("clickedAt") LocalDateTime clickedAt);

    @Modifying
    @Query("DELETE FROM EmailCampaignRecipient r WHERE r.campaign.id = :campaignId")
    void deleteByCampaignId(@Param("campaignId") UUID campaignId);
}
