package com.luma.dto.request;

import com.luma.entity.enums.PollType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

@Data
public class CreatePollRequest {

    @NotBlank
    @Size(max = 500)
    private String question;

    @NotNull
    private PollType type;

    @Size(min = 2, max = 10)
    private List<String> options;

    private Integer maxRating;

    private LocalDateTime closesAt;
}
