package com.luma.service;

import com.luma.dto.response.ConnectionResponse;
import com.luma.dto.response.NetworkingProfileResponse;
import com.luma.dto.response.PageResponse;
import com.luma.entity.ConnectionRequest;
import com.luma.entity.Registration;
import com.luma.entity.User;
import com.luma.entity.enums.ConnectionStatus;
import com.luma.entity.enums.RegistrationStatus;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.BlockedUserRepository;
import com.luma.repository.ConnectionRequestRepository;
import com.luma.repository.RegistrationRepository;
import com.luma.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class NetworkingService {

    private final ConnectionRequestRepository connectionRequestRepository;
    private final RegistrationRepository registrationRepository;
    private final BlockedUserRepository blockedUserRepository;
    private final UserRepository userRepository;
    private final UserService userService;
    private final NotificationService notificationService;

    @Transactional(readOnly = true)
    public List<NetworkingProfileResponse> getMatchedProfiles(User currentUser, Pageable pageable) {
        List<RegistrationStatus> activeStatuses = List.of(
                RegistrationStatus.APPROVED, RegistrationStatus.PENDING, RegistrationStatus.WAITING_LIST);

        List<Registration> myRegistrations = registrationRepository.findByUserAndStatusIn(currentUser, activeStatuses);
        if (myRegistrations.isEmpty()) return List.of();

        List<Registration> otherRegistrations = registrationRepository.findByEventInAndStatusIn(
                myRegistrations.stream().map(Registration::getEvent).toList(), activeStatuses);

        Map<UUID, Set<UUID>> userSharedEvents = new HashMap<>();
        for (Registration reg : otherRegistrations) {
            UUID userId = reg.getUser().getId();
            if (userId.equals(currentUser.getId())) continue;
            userSharedEvents.computeIfAbsent(userId, k -> new HashSet<>())
                    .add(reg.getEvent().getId());
        }

        Set<String> myInterests = parseInterests(currentUser.getInterests());

        Map<UUID, User> usersById = new HashMap<>();
        for (User u : userRepository.findAllById(userSharedEvents.keySet())) {
            usersById.put(u.getId(), u);
        }

        List<NetworkingProfileResponse> profiles = new ArrayList<>();
        for (Map.Entry<UUID, Set<UUID>> entry : userSharedEvents.entrySet()) {
            UUID userId = entry.getKey();
            User otherUser = usersById.get(userId);
            if (otherUser == null) continue;

            if (!otherUser.isNetworkingVisible()) continue;
            if (blockedUserRepository.existsByBlockerAndBlocked(currentUser, otherUser) ||
                blockedUserRepository.existsByBlockerAndBlocked(otherUser, currentUser)) {
                continue;
            }

            int sharedCount = entry.getValue().size();
            Set<String> theirInterests = parseInterests(otherUser.getInterests());
            double interestScore = calculateInterestScore(myInterests, theirInterests);
            double sharedEventScore = Math.min(sharedCount * 15.0, 50.0);
            long connections = connectionRequestRepository.countConnections(otherUser);
            double connectionScore = Math.min(connections * 2.0, 10.0);
            double compatibilityScore = interestScore + sharedEventScore + connectionScore;

            String connectionStatus = getConnectionStatus(currentUser, otherUser);

            profiles.add(NetworkingProfileResponse.builder()
                    .userId(otherUser.getId())
                    .fullName(otherUser.getFullName())
                    .avatarUrl(otherUser.getAvatarUrl())
                    .bio(otherUser.getBio())
                    .interests(new ArrayList<>(theirInterests))
                    .sharedEventsCount(sharedCount)
                    .connectionsCount((int) connections)
                    .compatibilityScore(Math.min(compatibilityScore, 100.0))
                    .connectionStatus(connectionStatus)
                    .build());
        }

        profiles.sort(Comparator.comparingDouble(NetworkingProfileResponse::getCompatibilityScore).reversed());

        int start = (int) pageable.getOffset();
        int end = Math.min(start + pageable.getPageSize(), profiles.size());
        if (start >= profiles.size()) return List.of();
        return profiles.subList(start, end);
    }

    @Transactional
    public ConnectionResponse sendConnectionRequest(User sender, UUID receiverId, String message) {
        if (sender.getId().equals(receiverId)) {
            throw new BadRequestException("Cannot send connection request to yourself");
        }

        User receiver = userService.getEntityById(receiverId);

        if (blockedUserRepository.existsByBlockerAndBlocked(receiver, sender)) {
            throw new BadRequestException("Cannot send connection request to this user");
        }

        boolean exists = connectionRequestRepository.existsBySenderAndReceiverAndStatusIn(
                sender, receiver, List.of(ConnectionStatus.PENDING, ConnectionStatus.ACCEPTED));
        boolean reverseExists = connectionRequestRepository.existsBySenderAndReceiverAndStatusIn(
                receiver, sender, List.of(ConnectionStatus.PENDING, ConnectionStatus.ACCEPTED));

        if (exists || reverseExists) {
            throw new BadRequestException("A connection request already exists between you and this user");
        }

        connectionRequestRepository.findBySenderAndReceiver(sender, receiver).ifPresent(old -> {
            if (old.getStatus() == ConnectionStatus.DECLINED) {
                connectionRequestRepository.delete(old);
                connectionRequestRepository.flush();
            }
        });

        ConnectionRequest request = ConnectionRequest.builder()
                .sender(sender)
                .receiver(receiver)
                .message(message)
                .build();

        request = connectionRequestRepository.save(request);
        log.info("Connection request sent from {} to {}", sender.getId(), receiverId);

        try {
            notificationService.sendNotification(
                    receiver,
                    "New Connection Request",
                    sender.getFullName() + " wants to connect with you" +
                            (message != null && !message.isBlank() ? ": " + message : ""),
                    com.luma.entity.enums.NotificationType.CONNECTION_REQUEST,
                    request.getId(),
                    "CONNECTION",
                    sender
            );
        } catch (Exception e) {
            log.error("Failed to send connection request notification: {}", e.getMessage());
        }

        return ConnectionResponse.fromEntity(request);
    }

    @Transactional
    public ConnectionResponse acceptRequest(UUID requestId, User user) {
        ConnectionRequest request = connectionRequestRepository.findById(requestId)
                .orElseThrow(() -> new ResourceNotFoundException("Connection request not found"));

        if (!request.getReceiver().getId().equals(user.getId())) {
            throw new BadRequestException("You can only accept requests sent to you");
        }

        if (request.getStatus() != ConnectionStatus.PENDING) {
            throw new BadRequestException("This request is no longer pending");
        }

        request.setStatus(ConnectionStatus.ACCEPTED);
        request.setRespondedAt(LocalDateTime.now());
        connectionRequestRepository.save(request);

        log.info("Connection accepted between {} and {}", request.getSender().getId(), user.getId());

        try {
            notificationService.sendNotification(
                    request.getSender(),
                    "Connection Accepted",
                    user.getFullName() + " accepted your connection request",
                    com.luma.entity.enums.NotificationType.CONNECTION_ACCEPTED,
                    request.getId(),
                    "CONNECTION",
                    user
            );
        } catch (Exception e) {
            log.error("Failed to send connection accepted notification: {}", e.getMessage());
        }

        return ConnectionResponse.fromEntity(request);
    }

    @Transactional
    public ConnectionResponse declineRequest(UUID requestId, User user) {
        ConnectionRequest request = connectionRequestRepository.findById(requestId)
                .orElseThrow(() -> new ResourceNotFoundException("Connection request not found"));

        if (!request.getReceiver().getId().equals(user.getId())) {
            throw new BadRequestException("You can only decline requests sent to you");
        }

        if (request.getStatus() != ConnectionStatus.PENDING) {
            throw new BadRequestException("This request is no longer pending");
        }

        request.setStatus(ConnectionStatus.DECLINED);
        request.setRespondedAt(LocalDateTime.now());
        connectionRequestRepository.save(request);

        return ConnectionResponse.fromEntity(request);
    }

    public PageResponse<ConnectionResponse> getPendingRequests(User user, Pageable pageable) {
        Page<ConnectionRequest> page = connectionRequestRepository.findPendingRequestsForUser(user, pageable);
        return PageResponse.from(page, ConnectionResponse::fromEntity);
    }

    public PageResponse<ConnectionResponse> getConnections(User user, Pageable pageable) {
        Page<ConnectionRequest> page = connectionRequestRepository.findAcceptedConnections(user, pageable);
        return PageResponse.from(page, ConnectionResponse::fromEntity);
    }

    private Set<String> parseInterests(String interests) {
        if (interests == null || interests.isBlank()) return Set.of();
        return Arrays.stream(interests.split(","))
                .map(String::trim)
                .map(String::toLowerCase)
                .filter(s -> !s.isEmpty())
                .collect(Collectors.toSet());
    }

    private double calculateInterestScore(Set<String> myInterests, Set<String> theirInterests) {
        if (myInterests.isEmpty() || theirInterests.isEmpty()) return 0;
        long common = myInterests.stream().filter(theirInterests::contains).count();
        int total = Math.max(myInterests.size(), theirInterests.size());
        return (double) common / total * 40.0;
    }

    private String getConnectionStatus(User currentUser, User otherUser) {
        if (connectionRequestRepository.areConnected(currentUser, otherUser)) return "CONNECTED";
        Optional<ConnectionRequest> sent = connectionRequestRepository.findBySenderAndReceiver(currentUser, otherUser);
        if (sent.isPresent() && sent.get().getStatus() == ConnectionStatus.PENDING) return "PENDING_SENT";
        Optional<ConnectionRequest> received = connectionRequestRepository.findBySenderAndReceiver(otherUser, currentUser);
        if (received.isPresent() && received.get().getStatus() == ConnectionStatus.PENDING) return "PENDING_RECEIVED";
        return "NONE";
    }
}
