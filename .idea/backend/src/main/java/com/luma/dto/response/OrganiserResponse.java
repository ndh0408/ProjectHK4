package com.luma.dto.response;

import com.luma.entity.OrganiserProfile;
import com.luma.entity.enums.UserStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OrganiserResponse {

    private UUID id;
    private String fullName;
    private String email;
    private String avatarUrl;
    private UserStatus status;
    private String displayName;
    private String bio;
    private String logoUrl;
    private String coverUrl;
    private String website;
    private String contactEmail;
    private String contactPhone;
    private boolean verified;
    private int totalEvents;
    private int totalFollowers;
    private long totalRegistrations;
    private String signatureUrl;

    private String organizationName;
    private int followersCount;

    public static OrganiserResponse fromEntity(OrganiserProfile profile) {
        return OrganiserResponse.builder()
                .id(profile.getUser().getId())
                .fullName(profile.getUser().getFullName())
                .email(profile.getUser().getEmail())
                .avatarUrl(profile.getUser().getAvatarUrl())
                .status(profile.getUser().getStatus())
                .displayName(profile.getDisplayName())
                .bio(profile.getBio())
                .logoUrl(profile.getLogoUrl())
                .coverUrl(profile.getCoverUrl())
                .website(profile.getWebsite())
                .contactEmail(profile.getContactEmail())
                .contactPhone(profile.getContactPhone())
                .verified(profile.isVerified())
                .totalEvents(profile.getTotalEvents())
                .totalFollowers(profile.getTotalFollowers())
                .totalRegistrations(0)
                .signatureUrl(profile.getUser().getSignatureUrl())
                .organizationName(profile.getDisplayName())
                .followersCount(profile.getTotalFollowers())
                .build();
    }

    public static OrganiserResponse fromEntityWithStats(OrganiserProfile profile, long totalRegistrations) {
        OrganiserResponse response = fromEntity(profile);
        response.setTotalRegistrations(totalRegistrations);
        return response;
    }

    public static OrganiserResponse fromEntityWithAllStats(OrganiserProfile profile, long totalEvents, long totalFollowers, long totalRegistrations) {
        OrganiserResponse response = fromEntity(profile);
        response.setTotalEvents((int) totalEvents);
        response.setTotalFollowers((int) totalFollowers);
        response.setFollowersCount((int) totalFollowers);
        response.setTotalRegistrations(totalRegistrations);
        return response;
    }
}
