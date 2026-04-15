package com.luma.dto.request;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class GeneratePollRequest {
    
    /**
     * Topic or context for poll generation
     * Example: "Event satisfaction", "Feature preference", "Demographic survey"
     */
    private String topic;
    
    /**
     * Number of options to generate (for SINGLE_CHOICE or MULTIPLE_CHOICE)
     * Valid range: 2-10
     */
    private Integer numOptions;
    
    /**
     * Poll type: SINGLE_CHOICE, MULTIPLE_CHOICE, or RATING
     * Default: SINGLE_CHOICE
     */
    private String pollType;
    
    /**
     * Max rating value (only for RATING type)
     * Default: 5
     */
    private Integer maxRating;
    
    /**
     * Number of poll questions to generate
     * Valid range: 1-5
     * Default: 1
     */
    private Integer numberOfQuestions;
    
    /**
     * Language for generated content
     * Default: "English"
     */
    private String language;
    
    /**
     * Additional context or instructions for AI generation
     * Example: "Focus on user experience improvements"
     */
    private String additionalContext;
}
