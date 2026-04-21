package com.luma.config;

import com.luma.entity.Conversation;
import com.luma.entity.User;
import com.luma.repository.ConversationParticipantRepository;
import com.luma.repository.ConversationRepository;
import com.luma.repository.UserRepository;
import com.luma.security.JwtService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.MessageDeliveryException;
import org.springframework.messaging.simp.config.ChannelRegistration;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

import java.security.Principal;
import java.util.Optional;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Configuration
@EnableWebSocketMessageBroker
@Order(Ordered.HIGHEST_PRECEDENCE + 99)
@RequiredArgsConstructor
@Slf4j
public class WebSocketSecurityConfig implements WebSocketMessageBrokerConfigurer {

    private final JwtService jwtService;
    private final UserDetailsService userDetailsService;
    // Break the circular bean graph: these repositories indirectly depend on
    // the security chain, so resolve them lazily at message-handling time.
    private final ObjectProvider<UserRepository> userRepositoryProvider;
    private final ObjectProvider<ConversationRepository> conversationRepositoryProvider;
    private final ObjectProvider<ConversationParticipantRepository> participantRepositoryProvider;

    private static final Pattern CONVERSATION_TOPIC =
            Pattern.compile("^/topic/conversation\\.([0-9a-fA-F-]{36})$");
    private static final Pattern CHAT_APP_DESTINATION =
            Pattern.compile("^/app/chat/([0-9a-fA-F-]{36})(?:/.*)?$");

    @Override
    public void configureClientInboundChannel(ChannelRegistration registration) {
        registration.interceptors(new ChannelInterceptor() {
            @Override
            public Message<?> preSend(Message<?> message, MessageChannel channel) {
                StompHeaderAccessor accessor =
                        MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);
                if (accessor == null) return message;

                StompCommand command = accessor.getCommand();
                if (command == null) return message;

                if (StompCommand.CONNECT.equals(command)) {
                    authenticate(accessor);
                    return message;
                }

                if (StompCommand.SUBSCRIBE.equals(command)) {
                    authorizeSubscribe(accessor);
                } else if (StompCommand.SEND.equals(command)) {
                    authorizeSend(accessor);
                }
                return message;
            }
        });
    }

    private void authenticate(StompHeaderAccessor accessor) {
        String authHeader = accessor.getFirstNativeHeader("Authorization");
        if (authHeader == null || !authHeader.startsWith("Bearer ")) return;

        String token = authHeader.substring(7);
        String username = jwtService.extractUsername(token);
        if (username == null) return;

        UserDetails userDetails = userDetailsService.loadUserByUsername(username);
        if (!jwtService.isTokenValid(token, userDetails)) return;

        UsernamePasswordAuthenticationToken authentication =
                new UsernamePasswordAuthenticationToken(
                        userDetails, null, userDetails.getAuthorities());
        SecurityContextHolder.getContext().setAuthentication(authentication);
        accessor.setUser(authentication);
    }

    private void authorizeSubscribe(StompHeaderAccessor accessor) {
        String destination = accessor.getDestination();
        if (destination == null) return;

        Matcher m = CONVERSATION_TOPIC.matcher(destination);
        if (!m.matches()) {
            // Allow other topics (/topic/presence, /user/queue/...) without check.
            return;
        }

        UUID conversationId = UUID.fromString(m.group(1));
        ensureParticipant(accessor.getUser(), conversationId, "subscribe");
    }

    private void authorizeSend(StompHeaderAccessor accessor) {
        String destination = accessor.getDestination();
        if (destination == null) return;

        Matcher m = CHAT_APP_DESTINATION.matcher(destination);
        if (!m.matches()) return;

        UUID conversationId = UUID.fromString(m.group(1));
        ensureParticipant(accessor.getUser(), conversationId, "send");
    }

    private void ensureParticipant(Principal principal, UUID conversationId, String action) {
        if (principal == null) {
            log.warn("Rejected chat WS {} for {}: unauthenticated", action, conversationId);
            throw new MessageDeliveryException("Authentication required");
        }

        UserRepository userRepo = userRepositoryProvider.getObject();
        ConversationRepository conversationRepo = conversationRepositoryProvider.getObject();
        ConversationParticipantRepository participantRepo = participantRepositoryProvider.getObject();

        Optional<User> userOpt = userRepo.findByEmail(principal.getName());
        if (userOpt.isEmpty()) {
            log.warn("Rejected chat WS {} for {}: user not found", action, conversationId);
            throw new MessageDeliveryException("User not found");
        }

        Optional<Conversation> conversationOpt = conversationRepo.findById(conversationId);
        if (conversationOpt.isEmpty()) {
            log.warn("Rejected chat WS {} for {}: conversation not found", action, conversationId);
            throw new MessageDeliveryException("Conversation not found");
        }

        boolean isMember = participantRepo.existsByConversationAndUser(
                conversationOpt.get(), userOpt.get());
        if (!isMember) {
            log.warn("Rejected chat WS {} by {} on {}: not a participant",
                    action, principal.getName(), conversationId);
            throw new MessageDeliveryException("Not a participant of this conversation");
        }
    }
}
