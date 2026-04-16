package com.luma.dto.response;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
@JsonInclude(JsonInclude.Include.NON_NULL)
public class AIGeneratedPollResponse {
    
    /**
     * The AI-generated poll question
     */
    private String question;
    
    /**
     * Poll type: SINGLE_CHOICE, MULTIPLE_CHOICE, or RATING
     */
    private String pollType;
    
    /**
     * List of generated options (for SINGLE_CHOICE or MULTIPLE_CHOICE)
     */
    private List<String> options;
    
    /**
     * Max rating value (for RATING type)
     */
    private Integer maxRating;
    
    /**
     * Explanation or description of why these options were generated
     */
    private String explanation;
    
    /**
     * List of multiple AI-generated polls
     */
    private List<AIGeneratedPollResponse> polls;
    
    /**
     * Model used for generation
     */
    private String model;
    
    /**
     * Generation timestamp
     */
    private long generatedAt;
}
