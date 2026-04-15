package com.luma.dto.response;

import com.luma.entity.Speaker;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SpeakerResponse {

    private Long id;
    private String name;
    private String title;
    private String bio;
    private String imageUrl;

    public static SpeakerResponse fromEntity(Speaker speaker) {
        return SpeakerResponse.builder()
                .id(speaker.getId())
                .name(speaker.getName())
                .title(speaker.getTitle())
                .bio(speaker.getBio())
                .imageUrl(speaker.getImageUrl())
                .build();
    }
}
