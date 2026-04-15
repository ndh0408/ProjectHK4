package com.luma.dto.response;

import com.luma.entity.ConnectionRequest;
import com.luma.entity.enums.ConnectionStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ConnectionResponse {

    private UUID id;
    private UUID senderId;
    private String senderName;
    private String senderAvatarUrl;
    private UUID receiverId;
    private String receiverName;
    private String receiverAvatarUrl;
    private ConnectionStatus status;
    private String message;
    private LocalDateTime createdAt;
    private LocalDateTime respondedAt;

    public static ConnectionResponse fromEntity(ConnectionRequest cr) {
        return ConnectionResponse.builder()
                .id(cr.getId())
                .senderId(cr.getSender().getId())
                .senderName(cr.getSender().getFullName())
                .senderAvatarUrl(cr.getSender().getAvatarUrl())
                .receiverId(cr.getReceiver().getId())
                .receiverName(cr.getReceiver().getFullName())
                .receiverAvatarUrl(cr.getReceiver().getAvatarUrl())
                .status(cr.getStatus())
                .message(cr.getMessage())
                .createdAt(cr.getCreatedAt())
                .respondedAt(cr.getRespondedAt())
                .build();
    }
}
