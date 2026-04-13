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
        Event event = eventService.getEntityById(eventId);

        if (!event.getOrganiser().getId().equals(organiser.getId())) {
            throw new BadRequestException("Only the event organiser can create polls");
        }

        Poll poll = Poll.builder()
                .event(event)
                .createdBy(organiser)
                .question(request.getQuestion())
                .type(request.getType())
                .allowMultiple(request.getType() == PollType.MULTIPLE_CHOICE)
                .maxRating(request.getType() == PollType.RATING ? (request.getMaxRating() != null ? request.getMaxRating() : 5) : null)
                .closesAt(request.getClosesAt())
                .build();

        poll = pollRepository.save(poll);

        if (request.getType() != PollType.RATING && request.getOptions() != null) {
            for (int i = 0; i < request.getOptions().size(); i++) {
                PollOption option = PollOption.builder()
                        .poll(poll)
                        .text(request.getOptions().get(i))
                        .displayOrder(i)
                        .build();
                poll.getOptions().add(option);
            }
            pollRepository.save(poll);
        }

        PollResponse response = PollResponse.fromEntity(poll, false);

        messagingTemplate.convertAndSend(
                "/topic/event." + eventId + ".polls",
                response
        );

        log.info("Poll created: {} for event {}", poll.getId(), eventId);
        return response;
    }

    @Transactional
    public PollResponse vote(UUID pollId, VotePollRequest request, User user) {
        Poll poll = pollRepository.findById(pollId)
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

        Poll updatedPoll = pollRepository.findById(pollId).orElse(poll);
        PollResponse response = PollResponse.fromEntity(updatedPoll, true);

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

    @Transactional(readOnly = true)
    public List<PollResponse> getEventPolls(UUID eventId, User user) {
        Event event = eventService.getEntityById(eventId);
        List<Poll> polls = pollRepository.findByEventOrderByCreatedAtDesc(event);

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
}
