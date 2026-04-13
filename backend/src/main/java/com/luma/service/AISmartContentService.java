package com.luma.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.luma.entity.Event;
import com.luma.entity.RegistrationQuestion;
import com.luma.repository.CategoryRepository;
import com.luma.repository.EventRepository;
import com.luma.repository.RegistrationQuestionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.*;

@Service
@Slf4j
@RequiredArgsConstructor
public class AISmartContentService {

    private final RestTemplate groqRestTemplate;
    private final ObjectMapper objectMapper;
    private final EventRepository eventRepository;
    private final CategoryRepository categoryRepository;
    private final RegistrationQuestionRepository registrationQuestionRepository;

    @Value("${groq.model:llama-3.3-70b-versatile}")
    private String model;

    private static final String GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions";

    @org.springframework.transaction.annotation.Transactional(readOnly = true)
    public Map<String, Object> generateEventDescriptionWithRAG(
            String title, Long categoryId, String venue,
            String address, String startTime, String endTime, String currentDescription) {

        StringBuilder ragContext = new StringBuilder();
        List<String> referenceTitles = new ArrayList<>();
        int referenceCount = 0;

        if (categoryId != null) {
            List<Event> topEvents = eventRepository.findTopEventsByCategory(
                    categoryId, PageRequest.of(0, 5));

            if (!topEvents.isEmpty()) {
                ragContext.append("\n=== TOP-PERFORMING EVENTS IN THIS CATEGORY (FOR INSPIRATION) ===\n");
                ragContext.append("These are real successful events. Learn from their structure and tone, ");
                ragContext.append("but DO NOT copy verbatim. Create something original.\n\n");

                for (Event ref : topEvents) {
                    if (referenceCount >= 3) break;
                    if (ref.getDescription() == null || ref.getDescription().length() < 100) continue;

                    ragContext.append("--- Reference Event ").append(referenceCount + 1).append(" ---\n");
                    ragContext.append("Title: ").append(ref.getTitle()).append("\n");
                    ragContext.append("Approved attendees: ").append(ref.getApprovedCount()).append("\n");

                    String descSnippet = ref.getDescription();
                    if (descSnippet.length() > 600) {
                        descSnippet = descSnippet.substring(0, 600) + "...";
                    }
                    ragContext.append("Description excerpt:\n").append(descSnippet).append("\n\n");

                    referenceTitles.add(ref.getTitle());
                    referenceCount++;
                }
            }
        }

        String systemPrompt = """
            You are an expert event marketing copywriter with access to a knowledge base of
            successful past events. Your task is to write a compelling event description.

            CRITICAL INSTRUCTIONS:
            1. STUDY the reference events provided in the user message — they are real successful events
            2. LEARN their structure, tone, and what makes them appealing
            3. CREATE an original description that follows similar patterns but is UNIQUE
            4. DO NOT copy phrases, sentences, or specific details from references
            5. Write in Markdown with sections: Overview, What to Expect, Who Should Attend
            6. Length: 150-250 words
            7. Detect language from the title (Vietnamese title → Vietnamese output)
            8. Do NOT include the event title in the description
            """;

        StringBuilder userPrompt = new StringBuilder();
        userPrompt.append("Generate a description for the new event below.\n");
        userPrompt.append("Use the reference events as inspiration for structure and quality.\n\n");

        userPrompt.append("=== NEW EVENT TO DESCRIBE ===\n");
        userPrompt.append("Title: ").append(title).append("\n");
        if (venue != null && !venue.isEmpty()) userPrompt.append("Venue: ").append(venue).append("\n");
        if (address != null && !address.isEmpty()) userPrompt.append("Address: ").append(address).append("\n");
        if (startTime != null && !startTime.isEmpty()) userPrompt.append("Start: ").append(startTime).append("\n");
        if (endTime != null && !endTime.isEmpty()) userPrompt.append("End: ").append(endTime).append("\n");
        if (currentDescription != null && !currentDescription.isBlank()) {
            userPrompt.append("\nCurrent draft (improve it):\n").append(currentDescription).append("\n");
        }

        if (ragContext.length() > 0) {
            userPrompt.append(ragContext);
        }

        String aiResponse = callGroqApi(systemPrompt, userPrompt.toString(), 800);

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("description", aiResponse);
        result.put("ragEnabled", referenceCount > 0);
        result.put("referencesUsed", referenceCount);
        result.put("inspirationFrom", referenceTitles);
        return result;
    }

    @org.springframework.transaction.annotation.Transactional(readOnly = true)
    public Map<String, Object> suggestRegistrationQuestionsWithRAG(
            String eventTitle, Long categoryId, String eventDescription, int numberOfQuestions) {

        StringBuilder ragContext = new StringBuilder();
        Set<String> existingQuestionTexts = new LinkedHashSet<>();
        int referencedQuestionsCount = 0;

        if (categoryId != null) {

            UUID sentinelExcludeId = new UUID(0L, 0L);
            List<RegistrationQuestion> similarQuestions = registrationQuestionRepository
                    .findQuestionsFromSimilarEvents(categoryId, sentinelExcludeId, PageRequest.of(0, 30));

            if (!similarQuestions.isEmpty()) {
                ragContext.append("\n=== EXISTING QUESTIONS FROM SUCCESSFUL EVENTS IN THIS CATEGORY ===\n");
                ragContext.append("These are real registration questions used by similar events.\n");
                ragContext.append("Use them as inspiration but create questions that fit the NEW event specifically.\n\n");

                int added = 0;
                for (RegistrationQuestion q : similarQuestions) {
                    String text = q.getQuestionText();
                    if (text == null || text.isBlank()) continue;
                    String normalized = text.trim().toLowerCase();
                    if (existingQuestionTexts.contains(normalized)) continue;
                    existingQuestionTexts.add(normalized);

                    ragContext.append("- [").append(q.getQuestionType()).append("] ").append(text);
                    if (q.isRequired()) ragContext.append(" (REQUIRED)");
                    ragContext.append("\n");

                    added++;
                    referencedQuestionsCount++;
                    if (added >= 12) break;
                }
                ragContext.append("\n");
            }
        }

        String systemPrompt = """
            You are an event organizer assistant. Generate registration form questions for an event.

            CRITICAL RULES:
            1. Return ONLY a valid JSON array - NO markdown, NO commentary, NO code fences
            2. STUDY the existing reference questions provided (if any) to understand what works
            3. Create UNIQUE questions tailored to the new event - do not copy verbatim
            4. Mix question types: TEXT, TEXTAREA, SINGLE_CHOICE, MULTIPLE_CHOICE
            5. For SINGLE_CHOICE/MULTIPLE_CHOICE: provide 3-5 options
            6. Mark essential questions as required: true
            7. Detect language from event title

            Schema:
            [
              {
                "questionText": "string",
                "questionType": "TEXT|TEXTAREA|SINGLE_CHOICE|MULTIPLE_CHOICE",
                "options": ["option1", "option2"] or null,
                "required": true|false
              }
            ]
            """;

        StringBuilder userPrompt = new StringBuilder();
        userPrompt.append("Generate ").append(numberOfQuestions).append(" registration questions for:\n\n");
        userPrompt.append("=== NEW EVENT ===\n");
        userPrompt.append("Title: ").append(eventTitle).append("\n");
        if (categoryId != null) {
            categoryRepository.findById(categoryId).ifPresent(c ->
                    userPrompt.append("Category: ").append(c.getName()).append("\n"));
        }
        if (eventDescription != null && !eventDescription.isBlank()) {
            String snippet = eventDescription.length() > 300
                    ? eventDescription.substring(0, 300) + "..." : eventDescription;
            userPrompt.append("Description: ").append(snippet).append("\n");
        }

        if (ragContext.length() > 0) {
            userPrompt.append(ragContext);
        }

        String aiResponse = callGroqApi(systemPrompt, userPrompt.toString(), 1000);

        Map<String, Object> result = new LinkedHashMap<>();
        try {
            String cleaned = cleanJsonResponse(aiResponse);
            Object parsed = objectMapper.readValue(cleaned, Object.class);
            result.put("questions", parsed);
        } catch (Exception e) {
            log.warn("Failed to parse AI questions response: {}", e.getMessage());
            result.put("questions", List.of());
            result.put("rawResponse", aiResponse);
        }
        result.put("ragEnabled", referencedQuestionsCount > 0);
        result.put("referencedQuestionsCount", referencedQuestionsCount);
        return result;
    }

    @org.springframework.transaction.annotation.Transactional(readOnly = true)
    public Map<String, Object> analyzeEventForModerationWithRAG(
            String title, String description, String organiserName,
            String category, Long categoryId,
            String venue, String startTime, Integer capacity, java.math.BigDecimal ticketPrice) {

        StringBuilder ragContext = new StringBuilder();
        int approvedRefs = 0;
        int rejectedRefs = 0;

        if (categoryId != null) {
            List<Event> approvedExamples = eventRepository.findTopEventsByCategory(
                    categoryId, PageRequest.of(0, 3));

            if (!approvedExamples.isEmpty()) {
                ragContext.append("\n=== APPROVED EVENTS IN SAME CATEGORY (POSITIVE EXAMPLES) ===\n");
                for (Event ex : approvedExamples) {
                    ragContext.append("- Title: ").append(ex.getTitle()).append("\n");
                    ragContext.append("  Venue: ").append(ex.getVenue() != null ? ex.getVenue() : "N/A").append("\n");
                    ragContext.append("  Capacity: ").append(ex.getCapacity()).append("\n");
                    ragContext.append("  Status: ").append(ex.getStatus()).append("\n\n");
                    approvedRefs++;
                }
            }
        }

        List<Event> rejectedExamples = eventRepository.findRecentRejectedEvents(PageRequest.of(0, 5));
        if (!rejectedExamples.isEmpty()) {
            ragContext.append("\n=== RECENTLY REJECTED EVENTS (NEGATIVE EXAMPLES — AVOID THESE PATTERNS) ===\n");
            for (Event ex : rejectedExamples) {
                if (rejectedRefs >= 3) break;
                ragContext.append("- Title: ").append(ex.getTitle()).append("\n");
                if (ex.getRejectionReason() != null) {
                    ragContext.append("  Rejection reason: ").append(ex.getRejectionReason()).append("\n");
                }
                ragContext.append("\n");
                rejectedRefs++;
            }
        }

        String systemPrompt = """
            You are a strict but fair content moderator for an event platform.
            You have access to historical moderation decisions to inform your judgment.

            CRITICAL INSTRUCTIONS:
            1. Compare the new event against the APPROVED examples — does it match the quality bar?
            2. Compare against REJECTED examples — does it share concerning patterns?
            3. Be objective and base your decision on evidence
            4. Return ONLY valid JSON, no commentary

            Decision criteria:
            - APPROVE: Matches quality standards, no red flags
            - NEEDS_REVIEW: Some concerns but not clearly bad — requires admin attention
            - REJECT: Clearly violates standards or matches rejected patterns

            Response schema:
            {
              "qualityScore": 0-100,
              "recommendation": "APPROVE|NEEDS_REVIEW|REJECT",
              "confidence": "HIGH|MEDIUM|LOW",
              "strengths": ["string"],
              "concerns": ["string"],
              "comparisonInsight": "How does this compare to approved/rejected examples?",
              "suggestedAction": "Specific actionable advice"
            }
            """;

        StringBuilder userPrompt = new StringBuilder();
        userPrompt.append("Analyze this event submission against historical decisions:\n\n");

        userPrompt.append("=== NEW EVENT SUBMISSION ===\n");
        userPrompt.append("Title: ").append(title).append("\n");
        userPrompt.append("Organiser: ").append(organiserName).append("\n");
        if (category != null) userPrompt.append("Category: ").append(category).append("\n");
        if (venue != null) userPrompt.append("Venue: ").append(venue).append("\n");
        if (startTime != null) userPrompt.append("Start time: ").append(startTime).append("\n");
        if (capacity != null) userPrompt.append("Capacity: ").append(capacity).append("\n");
        if (ticketPrice != null) userPrompt.append("Ticket price: $").append(ticketPrice).append("\n");
        userPrompt.append("\nDescription:\n").append(description).append("\n");

        if (ragContext.length() > 0) {
            userPrompt.append(ragContext);
        }

        String aiResponse = callGroqApi(systemPrompt, userPrompt.toString(), 1000);

        Map<String, Object> result = new LinkedHashMap<>();
        try {
            String cleaned = cleanJsonResponse(aiResponse);
            Map<String, Object> parsed = objectMapper.readValue(cleaned, Map.class);
            result.putAll(parsed);
        } catch (Exception e) {
            log.warn("Failed to parse moderation response: {}", e.getMessage());
            result.put("recommendation", "NEEDS_REVIEW");
            result.put("error", "AI response parsing failed");
            result.put("rawResponse", aiResponse);
        }
        result.put("ragEnabled", approvedRefs > 0 || rejectedRefs > 0);
        result.put("approvedExamplesUsed", approvedRefs);
        result.put("rejectedExamplesUsed", rejectedRefs);
        return result;
    }

    private String callGroqApi(String systemPrompt, String userPrompt, int maxTokens) {
        try {
            Map<String, Object> requestBody = new LinkedHashMap<>();
            requestBody.put("model", model);
            requestBody.put("max_tokens", maxTokens);
            requestBody.put("temperature", 0.7);

            List<Map<String, String>> messages = new ArrayList<>();
            Map<String, String> systemMessage = new LinkedHashMap<>();
            systemMessage.put("role", "system");
            systemMessage.put("content", systemPrompt);
            messages.add(systemMessage);

            Map<String, String> userMessage = new LinkedHashMap<>();
            userMessage.put("role", "user");
            userMessage.put("content", userPrompt);
            messages.add(userMessage);

            requestBody.put("messages", messages);

            String requestJson = objectMapper.writeValueAsString(requestBody);

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);

            HttpEntity<String> entity = new HttpEntity<>(requestJson, headers);
            String responseStr = groqRestTemplate.postForObject(GROQ_API_URL, entity, String.class);

            if (responseStr == null || responseStr.isBlank()) {
                log.warn("Groq API returned empty response");
                return "";
            }

            JsonNode responseJson = objectMapper.readTree(responseStr);
            JsonNode choices = responseJson.get("choices");

            if (choices != null && choices.isArray() && choices.size() > 0) {
                JsonNode firstChoice = choices.get(0);
                if (firstChoice == null) return "";
                JsonNode message = firstChoice.get("message");
                if (message == null) return "";
                JsonNode content = message.get("content");
                if (content == null || content.isNull()) return "";
                return content.asText().trim();
            }

            return "";
        } catch (Exception e) {
            log.error("Error calling Groq API: ", e);
            return "";
        }
    }

    private String cleanJsonResponse(String response) {
        if (response == null) return "{}";
        String cleaned = response.trim();
        if (cleaned.startsWith("```json")) {
            cleaned = cleaned.substring(7);
        } else if (cleaned.startsWith("```")) {
            cleaned = cleaned.substring(3);
        }
        if (cleaned.endsWith("```")) {
            cleaned = cleaned.substring(0, cleaned.length() - 3);
        }
        return cleaned.trim();
    }
}
