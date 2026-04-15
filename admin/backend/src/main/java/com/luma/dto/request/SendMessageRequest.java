package com.luma.dto.request;

import com.luma.entity.enums.MessageType;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

import java.util.UUID;

@Data
public class SendMessageRequest {

    @NotBlank(message = "Message content is required")
    private String content;

    private MessageType type = MessageType.TEXT;

    private String mediaUrl;

    private UUID replyToId;
}
