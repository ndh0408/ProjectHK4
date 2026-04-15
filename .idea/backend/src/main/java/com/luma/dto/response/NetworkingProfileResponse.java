package com.luma.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class NetworkingProfileResponse {

    private UUID userId;
    private String fullName;
    private String avatarUrl;
    private String bio;
    private List<String> interests;
    private int sharedEventsCount;
    private int connectionsCount;
    private double compatibilityScore;
    private String connectionStatus;
}
