package com.luma.scheduler;

import com.luma.entity.WaitlistOffer;
import com.luma.repository.WaitlistOfferRepository;
import com.luma.service.WaitlistService;
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
public class WaitlistOfferScheduler {

    private final WaitlistOfferRepository waitlistOfferRepository;
    private final WaitlistService waitlistService;

    @Scheduled(fixedRate = 60000)
    @Transactional
    public void expireWaitlistOffers() {
        List<WaitlistOffer> expiredOffers = waitlistOfferRepository.findExpiredOffers(LocalDateTime.now());

        if (expiredOffers.isEmpty()) return;

        log.info("Found {} expired waitlist offers to process", expiredOffers.size());

        for (WaitlistOffer offer : expiredOffers) {
            try {
                waitlistService.expireOffer(offer);
            } catch (Exception e) {
                log.error("Failed to expire waitlist offer {}: {}", offer.getId(), e.getMessage());
            }
        }
    }
}
