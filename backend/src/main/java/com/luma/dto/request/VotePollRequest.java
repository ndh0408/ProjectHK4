package com.luma.dto.request;

import lombok.Data;

import java.util.List;
import java.util.UUID;

@Data
public class VotePollRequest {

    private List<UUID> optionIds;

    private Integer ratingValue;
}
