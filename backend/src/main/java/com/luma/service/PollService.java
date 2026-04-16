package com.luma.service;

import com.luma.dto.request.CreatePollRequest;
import com.luma.dto.request.VotePollRequest;
import com.luma.dto.response.PollResponse;
import com.luma.entity.*;
import com.luma.entity.enums.PollStatus;
import com.luma.entity.enums.PollType;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.PollOptionRepository;
import com.luma.repository.PollRepository;
import com.luma.repository.PollVoteRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class PollService {

    private final PollRepository pollRepository;
    private final PollOptionRepository pollOptionRepository;
    private final PollVoteRepository pollVoteRepository;
    private final EventService eventService;
    private final SimpMessagingTemplate messagingTemplate;

    @Transactional
    public PollResponse createPoll(UUID eventId, CreatePollRequest request, User organiser) {
        log.info("Creating poll for event: {} by user: {}", eventId, organiser.getEmail());
        Event event = eventService.getEntityById(eventId);
        log.info("Event found: {} (organiser: {})", event.getId(), event.getOrganiser().getId());

        if (!event.getOrganiser().getId().equals(organiser.getId())) {
            log.error("User {} is not the organiser of event {}", organiser.getId(), eventId);
            throw new BadRequestException("Only the event organiser can create polls");
        }

        // Xác định trạng thái ban đầu
        PollStatus initialStatus = Boolean.TRUE.equals(request.getDraft()) ? PollStatus.DRAFT : PollStatus.ACTIVE;
        LocalDateTime scheduledOpenAt = request.getScheduledOpenAt();

        // Nếu có lên lịch mở, chuyển sang SCHEDULED
        if (scheduledOpenAt != null && scheduledOpenAt.isAfter(LocalDateTime.now())) {
            initialStatus = PollStatus.SCHEDULED;
        }

        // Xử lý closesAt nếu chọn autoCloseTenDaysAfterEventEnd
        LocalDateTime closesAt = request.getClosesAt();
        if (request.isAutoCloseTenDaysAfterEventEnd() && event.getEndTime() != null) {
            closesAt = event.getEndTime().plusDays(10);
            log.info("Setting poll closesAt to 10 days after event end: {}", closesAt);
        }

        // Build options first if not RATING type
        List<PollOption> options = new ArrayList<>();
        if (request.getType() != PollType.RATING && request.getOptions() != null) {
            log.info("Creating {} options for poll", request.getOptions().size());
            for (int i = 0; i < request.getOptions().size(); i++) {
                PollOption option = PollOption.builder()
                        .text(request.getOptions().get(i))
                        .displayOrder(i)
                        .build();
                options.add(option);
            }
        }

        Poll poll = Poll.builder()
                .event(event)
                .createdBy(organiser)
                .question(request.getQuestion())
                .type(request.getType())
                .status(initialStatus)
                .allowMultiple(request.getType() == PollType.MULTIPLE_CHOICE)
                .maxRating(request.getType() == PollType.RATING ? (request.getMaxRating() != null ? request.getMaxRating() : 5) : null)
                .closesAt(closesAt)
                .scheduledOpenAt(scheduledOpenAt)
                .closeAtVoteCount(request.getCloseAtVoteCount())
                .autoOpenEventStart(request.isAutoOpenEventStart())
                .autoCloseEventEnd(request.isAutoCloseEventEnd())
                .autoCloseTenDaysAfterEventEnd(request.isAutoCloseTenDaysAfterEventEnd())
                .hideResultsUntilClosed(request.isHideResultsUntilClosed())
                .options(options)
                .build();

        // Set poll reference for each option
        for (PollOption option : options) {
            option.setPoll(poll);
        }

        poll = pollRepository.save(poll);
        log.info("Poll saved with ID: {}, status: {} with {} options", poll.getId(), poll.getStatus(), options.size());

        // Chỉ broadcast nếu poll ACTIVE hoặc SCHEDULED
        if (poll.getStatus() == PollStatus.ACTIVE || poll.getStatus() == PollStatus.SCHEDULED) {
            PollResponse response = PollResponse.fromEntity(poll, false);
            messagingTemplate.convertAndSend(
                    "/topic/event." + eventId + ".polls",
                    response
            );
        }

        log.info("Poll created: {} for event {} with status {}", poll.getId(), eventId, poll.getStatus());
        return PollResponse.fromEntity(poll, false);
    }

    @Transactional
    public PollResponse vote(UUID pollId, VotePollRequest request, User user) {
        Poll poll = pollRepository.findByIdWithOptions(pollId)
                .orElseThrow(() -> new ResourceNotFoundException("Poll not found"));

        if (!poll.isActive()) {
            throw new BadRequestException("This poll is no longer active");
        }

        if (pollVoteRepository.existsByPollAndUser(poll, user)) {
            throw new BadRequestException("You have already voted on this poll");
        }

        if (poll.getType() == PollType.RATING) {
            if (request.getRatingValue() == null) {
                throw new BadRequestException("Rating value is required");
            }
            int max = poll.getMaxRating() != null ? poll.getMaxRating() : 5;
            if (request.getRatingValue() < 1 || request.getRatingValue() > max) {
                throw new BadRequestException("Rating must be between 1 and " + max);
            }

            PollVote vote = PollVote.builder()
                    .poll(poll)
                    .user(user)
                    .ratingValue(request.getRatingValue())
                    .build();
            pollVoteRepository.save(vote);
            poll.setTotalVotes(poll.getTotalVotes() + 1);
        } else {
            if (request.getOptionIds() == null || request.getOptionIds().isEmpty()) {
                throw new BadRequestException("At least one option must be selected");
            }

            if (!poll.isAllowMultiple() && request.getOptionIds().size() > 1) {
                throw new BadRequestException("Only one option can be selected for this poll");
            }

            for (UUID optionId : request.getOptionIds()) {
                PollOption option = pollOptionRepository.findById(optionId)
                        .orElseThrow(() -> new ResourceNotFoundException("Poll option not found"));

                if (!option.getPoll().getId().equals(pollId)) {
                    throw new BadRequestException("Option does not belong to this poll");
                }

                PollVote vote = PollVote.builder()
                        .poll(poll)
                        .user(user)
                        .option(option)
                        .build();
                pollVoteRepository.save(vote);
                pollOptionRepository.incrementVoteCount(optionId);
            }
            poll.setTotalVotes(poll.getTotalVotes() + 1);
        }

        pollRepository.save(poll);

        // Kiểm tra auto-close theo số vote
        if (poll.shouldAutoCloseByVoteCount()) {
            poll.setStatus(PollStatus.CLOSED);
            poll.setClosedAt(LocalDateTime.now());
            pollRepository.save(poll);
            log.info("Poll {} auto-closed after reaching {} votes", pollId, poll.getTotalVotes());
        }

        Poll updatedPoll = pollRepository.findById(pollId).orElse(poll);
        // Nếu hideResultsUntilClosed = true và poll chưa đóng, ẩn kết quả
        boolean hideResults = poll.isHideResultsUntilClosed() && poll.getStatus() != PollStatus.CLOSED;
        PollResponse response = PollResponse.fromEntity(updatedPoll, true, hideResults);

        messagingTemplate.convertAndSend(
                "/topic/event." + poll.getEvent().getId() + ".polls",
                response
        );

        return response;
    }

    @Transactional
    public PollResponse closePoll(UUID pollId, User organiser) {
        Poll poll = pollRepository.findById(pollId)
                .orElseThrow(() -> new ResourceNotFoundException("Poll not found"));

        if (!poll.getCreatedBy().getId().equals(organiser.getId())) {
            throw new BadRequestException("Only the poll creator can close it");
        }

        if (poll.getStatus() == PollStatus.CLOSED) {
            throw new BadRequestException("Poll is already closed");
        }

        poll.setStatus(PollStatus.CLOSED);
        poll.setClosedAt(LocalDateTime.now());
        pollRepository.save(poll);

        PollResponse response = PollResponse.fromEntity(poll, false);

        messagingTemplate.convertAndSend(
                "/topic/event." + poll.getEvent().getId() + ".polls",
                response
        );

        return response;
    }

    // ==================== STATE TRANSITIONS ====================

    /**
     * Publish poll: DRAFT → SCHEDULED (nếu có scheduledOpenAt) hoặc ACTIVE
     */
    @Transactional
    public PollResponse publishPoll(UUID pollId, User organiser) {
        Poll poll = pollRepository.findById(pollId)
                .orElseThrow(() -> new ResourceNotFoundException("Poll not found"));

        if (!poll.getCreatedBy().getId().equals(organiser.getId())) {
            throw new BadRequestException("Only the poll creator can publish it");
        }

        if (!poll.canPublish()) {
            throw new BadRequestException("Poll is not in DRAFT state");
        }

        // Nếu có scheduledOpenAt và chưa đến giờ → SCHEDULED
        if (poll.getScheduledOpenAt() != null
                && poll.getScheduledOpenAt().isAfter(LocalDateTime.now())) {
            poll.setStatus(PollStatus.SCHEDULED);
            log.info("Poll {} scheduled to open at {}", pollId, poll.getScheduledOpenAt());
        } else {
            // Ngược lại → ACTIVE ngay
            poll.setStatus(PollStatus.ACTIVE);
            poll.setOpenedAt(LocalDateTime.now());
            log.info("Poll {} published and activated immediately", pollId);
        }

        poll = pollRepository.save(poll);

        PollResponse response = PollResponse.fromEntity(poll, false);
        messagingTemplate.convertAndSend(
                "/topic/event." + poll.getEvent().getId() + ".polls",
                response
        );

        return response;
    }

    /**
     * Schedule poll với thời gian mở cụ thể: DRAFT → SCHEDULED
     */
    @Transactional
    public PollResponse schedulePoll(UUID pollId, LocalDateTime openAt, User organiser) {
        Poll poll = pollRepository.findById(pollId)
                .orElseThrow(() -> new ResourceNotFoundException("Poll not found"));

        if (!poll.getCreatedBy().getId().equals(organiser.getId())) {
            throw new BadRequestException("Only the poll creator can schedule it");
        }

        if (!poll.canPublish()) {
            throw new BadRequestException("Poll is not in DRAFT state");
        }

        if (openAt == null || openAt.isBefore(LocalDateTime.now())) {
            throw new BadRequestException("Scheduled open time must be in the future");
        }

        poll.setScheduledOpenAt(openAt);
        poll.setStatus(PollStatus.SCHEDULED);
        poll = pollRepository.save(poll);

        log.info("Poll {} scheduled to open at {} by {}", pollId, openAt, organiser.getEmail());

        PollResponse response = PollResponse.fromEntity(poll, false);
        messagingTemplate.convertAndSend(
                "/topic/event." + poll.getEvent().getId() + ".polls",
                response
        );

        return response;
    }

    /**
     * Open poll ngay lập tức: SCHEDULED → ACTIVE
     */
    @Transactional
    public PollResponse openPoll(UUID pollId, User organiser) {
        Poll poll = pollRepository.findById(pollId)
                .orElseThrow(() -> new ResourceNotFoundException("Poll not found"));

        if (!poll.getCreatedBy().getId().equals(organiser.getId())) {
            throw new BadRequestException("Only the poll creator can open it");
        }

        if (!poll.canOpen()) {
            throw new BadRequestException("Poll is not in SCHEDULED state");
        }

        poll.setStatus(PollStatus.ACTIVE);
        poll.setOpenedAt(LocalDateTime.now());
        poll = pollRepository.save(poll);

        log.info("Poll {} opened manually by {}", pollId, organiser.getEmail());

        PollResponse response = PollResponse.fromEntity(poll, false);
        messagingTemplate.convertAndSend(
                "/topic/event." + poll.getEvent().getId() + ".polls",
                response
        );

        return response;
    }

    /**
     * Reopen poll: CLOSED → ACTIVE
     */
    @Transactional
    public PollResponse reopenPoll(UUID pollId, User organiser) {
        Poll poll = pollRepository.findById(pollId)
                .orElseThrow(() -> new ResourceNotFoundException("Poll not found"));

        if (!poll.getCreatedBy().getId().equals(organiser.getId())) {
            throw new BadRequestException("Only the poll creator can reopen it");
        }

        if (!poll.canReopen()) {
            throw new BadRequestException("Poll is not in CLOSED state");
        }

        // Reset closedAt và openedAt
        poll.setStatus(PollStatus.ACTIVE);
        poll.setClosedAt(null);
        poll.setOpenedAt(LocalDateTime.now());

        // Reset closesAt nếu đã quá hạn
        if (poll.getClosesAt() != null && poll.getClosesAt().isBefore(LocalDateTime.now())) {
            poll.setClosesAt(null);  // Người dùng sẽ cần set lại
        }

        poll = pollRepository.save(poll);

        log.info("Poll {} reopened by {}", pollId, organiser.getEmail());

        PollResponse response = PollResponse.fromEntity(poll, false);
        messagingTemplate.convertAndSend(
                "/topic/event." + poll.getEvent().getId() + ".polls",
                response
        );

        return response;
    }

    /**
     * Cancel poll: DRAFT/SCHEDULED → CANCELLED
     */
    @Transactional
    public PollResponse cancelPoll(UUID pollId, User organiser) {
        Poll poll = pollRepository.findById(pollId)
                .orElseThrow(() -> new ResourceNotFoundException("Poll not found"));

        if (!poll.getCreatedBy().getId().equals(organiser.getId())) {
            throw new BadRequestException("Only the poll creator can cancel it");
        }

        if (!poll.canCancel()) {
            throw new BadRequestException("Cannot cancel poll in state: " + poll.getStatus());
        }

        poll.setStatus(PollStatus.CANCELLED);
        poll = pollRepository.save(poll);

        log.info("Poll {} cancelled by {}", pollId, organiser.getEmail());

        PollResponse response = PollResponse.fromEntity(poll, false);
        messagingTemplate.convertAndSend(
                "/topic/event." + poll.getEvent().getId() + ".polls",
                response
        );

        return response;
    }

    // ==================== END STATE TRANSITIONS ====================

    @Transactional(readOnly = true)
    public List<PollResponse> getEventPolls(UUID eventId, User user) {
        log.info("Getting polls for event: {}", eventId);
        Event event = eventService.getEntityById(eventId);
        log.info("Event found: {} (org: {})", event.getId(), event.getOrganiser().getId());

        List<Poll> polls = pollRepository.findByEventIdOrderByCreatedAtDesc(eventId);
        log.info("Query returned {} polls for event {}", polls.size(), eventId);

        // Log all poll IDs found
        for (Poll poll : polls) {
            log.info("  - Poll: {} | Q: {} | Status: {}", poll.getId(), poll.getQuestion(), poll.getStatus());
        }

        return polls.stream()
                .map(poll -> {
                    boolean hasVoted = user != null && pollVoteRepository.existsByPollAndUser(poll, user);
                    return PollResponse.fromEntity(poll, hasVoted);
                })
                .toList();
    }

    @Transactional(readOnly = true)
    public List<PollResponse> getActiveEventPolls(UUID eventId, User user) {
        Event event = eventService.getEntityById(eventId);
        List<Poll> polls = pollRepository.findActiveByEvent(event, LocalDateTime.now());
        log.info("Found {} active polls for event {}", polls.size(), eventId);

        return polls.stream()
                .map(poll -> {
                    boolean hasVoted = user != null && pollVoteRepository.existsByPollAndUser(poll, user);
                    return PollResponse.fromEntity(poll, hasVoted);
                })
                .toList();
    }

    @Transactional
    public void autoCloseExpiredPolls() {
        List<Poll> expired = pollRepository.findExpiredActivePolls(LocalDateTime.now());
        for (Poll poll : expired) {
            poll.setStatus(PollStatus.CLOSED);
            poll.setClosedAt(LocalDateTime.now());
            pollRepository.save(poll);

            messagingTemplate.convertAndSend(
                    "/topic/event." + poll.getEvent().getId() + ".polls",
                    PollResponse.fromEntity(poll, false)
            );
        }
        if (!expired.isEmpty()) {
            log.info("Auto-closed {} expired polls", expired.size());
        }
    }

    /**
     * Tự động mở các poll đã được lên lịch (SCHEDULED → ACTIVE)
     */
    @Transactional
    public void autoOpenScheduledPolls() {
        List<Poll> readyToOpen = pollRepository.findReadyToOpenPolls(LocalDateTime.now());
        for (Poll poll : readyToOpen) {
            poll.setStatus(PollStatus.ACTIVE);
            poll.setOpenedAt(LocalDateTime.now());
            pollRepository.save(poll);

            messagingTemplate.convertAndSend(
                    "/topic/event." + poll.getEvent().getId() + ".polls",
                    PollResponse.fromEntity(poll, false)
            );

            log.info("Auto-opened poll {} at scheduled time {}", poll.getId(), poll.getScheduledOpenAt());
        }
        if (!readyToOpen.isEmpty()) {
            log.info("Auto-opened {} scheduled polls", readyToOpen.size());
        }
    }

    /**
     * Tự động đóng poll khi event kết thúc
     */
    @Transactional
    public void autoClosePollsByEventEnd() {
        List<Poll> pollsToClose = pollRepository.findActivePollsByEventEndTime(LocalDateTime.now());
        for (Poll poll : pollsToClose) {
            if (poll.isAutoCloseEventEnd()) {
                poll.setStatus(PollStatus.CLOSED);
                poll.setClosedAt(LocalDateTime.now());
                pollRepository.save(poll);

                messagingTemplate.convertAndSend(
                        "/topic/event." + poll.getEvent().getId() + ".polls",
                        PollResponse.fromEntity(poll, false)
                );

                log.info("Auto-closed poll {} because event ended", poll.getId());
            }
        }
        if (!pollsToClose.isEmpty()) {
            log.info("Auto-closed {} polls due to event end", pollsToClose.size());
        }
    }

    /**
     * Tự động đóng poll sau 10 ngày kể từ khi event kết thúc
     */
    @Transactional
    public void autoClosePollsTenDaysAfterEventEnd() {
        LocalDateTime tenDaysAgo = LocalDateTime.now().minusDays(10);
        List<Poll> pollsToClose = pollRepository.findActivePollsTenDaysAfterEventEnd(tenDaysAgo);
        for (Poll poll : pollsToClose) {
            poll.setStatus(PollStatus.CLOSED);
            poll.setClosedAt(LocalDateTime.now());
            pollRepository.save(poll);

            messagingTemplate.convertAndSend(
                    "/topic/event." + poll.getEvent().getId() + ".polls",
                    PollResponse.fromEntity(poll, false)
            );

            log.info("Auto-closed poll {} (10 days after event ended)", poll.getId());
        }
        if (!pollsToClose.isEmpty()) {
            log.info("Auto-closed {} polls (10 days after event end)", pollsToClose.size());
        }
    }

    /**
     * Tự động mở poll khi event bắt đầu
     */
    @Transactional
    public void autoOpenPollsByEventStart() {
        List<Poll> pollsToOpen = pollRepository.findScheduledPollsByEventStartTime(LocalDateTime.now());
        for (Poll poll : pollsToOpen) {
            if (poll.isAutoOpenEventStart()) {
                poll.setStatus(PollStatus.ACTIVE);
                poll.setOpenedAt(LocalDateTime.now());
                pollRepository.save(poll);

                messagingTemplate.convertAndSend(
                        "/topic/event." + poll.getEvent().getId() + ".polls",
                        PollResponse.fromEntity(poll, false)
                );

                log.info("Auto-opened poll {} because event started", poll.getId());
            }
        }
        if (!pollsToOpen.isEmpty()) {
            log.info("Auto-opened {} polls due to event start", pollsToOpen.size());
        }
    }

    /**
     * Kiểm tra và đóng poll đủ số vote
     */
    @Transactional
    public void autoCloseByVoteCount() {
        List<Poll> polls = pollRepository.findActivePollsWithVoteLimit();
        for (Poll poll : polls) {
            if (poll.shouldAutoCloseByVoteCount()) {
                poll.setStatus(PollStatus.CLOSED);
                poll.setClosedAt(LocalDateTime.now());
                pollRepository.save(poll);

                messagingTemplate.convertAndSend(
                        "/topic/event." + poll.getEvent().getId() + ".polls",
                        PollResponse.fromEntity(poll, false)
                );

                log.info("Auto-closed poll {} after reaching {} votes", poll.getId(), poll.getTotalVotes());
            }
        }
    }

    @Transactional
    public PollResponse updatePoll(UUID pollId, CreatePollRequest request, User organiser) {
        Poll poll = pollRepository.findById(pollId)
                .orElseThrow(() -> new ResourceNotFoundException("Poll not found"));

        // Only allow editing if poll has no votes
        if (poll.getTotalVotes() > 0) {
            throw new BadRequestException("Cannot edit a poll that has received votes");
        }

        if (!poll.getCreatedBy().getId().equals(organiser.getId())) {
            throw new BadRequestException("Only the poll creator can edit it");
        }

        poll.setQuestion(request.getQuestion());
        poll.setType(request.getType());
        poll.setAllowMultiple(request.getType() == PollType.MULTIPLE_CHOICE);
        poll.setMaxRating(request.getType() == PollType.RATING ? request.getMaxRating() : null);
        poll.setClosesAt(request.getClosesAt());

        // Update options if not RATING type
        if (request.getType() != PollType.RATING && request.getOptions() != null) {
            // Remove existing options
            poll.getOptions().clear();

            // Add new options
            for (int i = 0; i < request.getOptions().size(); i++) {
                PollOption option = PollOption.builder()
                        .poll(poll)
                        .text(request.getOptions().get(i))
                        .displayOrder(i)
                        .build();
                poll.getOptions().add(option);
            }
        }

        poll = pollRepository.save(poll);
        log.info("Poll updated: {} by user {}", pollId, organiser.getEmail());

        return PollResponse.fromEntity(poll, false);
    }

    @Transactional
    public void deletePoll(UUID pollId, User organiser) {
        Poll poll = pollRepository.findById(pollId)
                .orElseThrow(() -> new ResourceNotFoundException("Poll not found"));

        if (!poll.getCreatedBy().getId().equals(organiser.getId())) {
            throw new BadRequestException("Only the poll creator can delete it");
        }

        UUID eventId = poll.getEvent().getId();

        // Delete all votes first
        List<PollVote> votes = pollVoteRepository.findByPoll(poll);
        if (!votes.isEmpty()) {
            pollVoteRepository.deleteAll(votes);
        }

        // Delete the poll (options will be cascade deleted)
        pollRepository.delete(poll);

        // Notify clients that poll has been deleted
        messagingTemplate.convertAndSend(
                "/topic/event." + eventId + ".polls.deleted",
                pollId.toString()
        );

        log.info("Poll deleted: {} by user {}", pollId, organiser.getEmail());
    }

    @Transactional
    public PollResponse extendPoll(UUID pollId, Integer hours, Integer days, String customTime, User organiser) {
        Poll poll = pollRepository.findById(pollId)
                .orElseThrow(() -> new ResourceNotFoundException("Poll not found"));

        if (!poll.getCreatedBy().getId().equals(organiser.getId())) {
            throw new BadRequestException("Only the poll creator can extend it");
        }

        if (poll.getStatus() == PollStatus.CLOSED) {
            throw new BadRequestException("Cannot extend a closed poll");
        }

        LocalDateTime newClosesAt;
        if (customTime != null && !customTime.isEmpty()) {
            newClosesAt = LocalDateTime.parse(customTime);
        } else {
            LocalDateTime baseTime = poll.getClosesAt() != null && poll.getClosesAt().isAfter(LocalDateTime.now())
                    ? poll.getClosesAt()
                    : LocalDateTime.now();
            newClosesAt = baseTime;
            if (hours != null) {
                newClosesAt = newClosesAt.plusHours(hours);
            }
            if (days != null) {
                newClosesAt = newClosesAt.plusDays(days);
            }
        }

        if (newClosesAt.isBefore(LocalDateTime.now())) {
            throw new BadRequestException("New closing time must be in the future");
        }

        poll.setClosesAt(newClosesAt);
        poll = pollRepository.save(poll);

        PollResponse response = PollResponse.fromEntity(poll, false);

        messagingTemplate.convertAndSend(
                "/topic/event." + poll.getEvent().getId() + ".polls",
                response
        );

        log.info("Poll {} extended to {} by user {}", pollId, newClosesAt, organiser.getEmail());
        return response;
    }
}
