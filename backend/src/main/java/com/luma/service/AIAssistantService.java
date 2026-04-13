package com.luma.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.luma.entity.Event;
import com.luma.entity.User;
import com.luma.repository.CategoryRepository;
import com.luma.repository.CityRepository;
import com.luma.repository.EventRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;

@Service
@Slf4j
@RequiredArgsConstructor
public class AIAssistantService {

    private final RestTemplate groqRestTemplate;
    private final ObjectMapper objectMapper;
    private final EventRepository eventRepository;
    private final CategoryRepository categoryRepository;
    private final CityRepository cityRepository;

    @Value("${groq.model:llama-3.3-70b-versatile}")
    private String model;

    private static final String GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions";

    @org.springframework.transaction.annotation.Transactional(readOnly = true)
    public Map<String, Object> chat(String userMessage, User user) {
        Map<String, Object> intent = detectIntent(userMessage);

        String intentType = (String) intent.getOrDefault("intent", "GENERAL_QUERY");
        log.info("AI Assistant detected intent: {} for user {}", intentType, user != null ? user.getId() : "anonymous");

        Map<String, Object> retrievedData = executeFunction(intentType, intent, user);

        String naturalResponse = generateResponse(userMessage, intentType, retrievedData);

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("response", naturalResponse);
        result.put("intent", intentType);
        result.put("data", retrievedData);
        result.put("dataPointsUsed", countDataPoints(retrievedData));
        return result;
    }

    private Map<String, Object> detectIntent(String userMessage) {
        String systemPrompt = """
            You are an intent classifier for an event marketplace assistant.
            Analyze the user message and return ONLY valid JSON (no markdown, no commentary).

            Available intents:
            - SEARCH_EVENTS: User wants to find events by keyword/category/city
            - RECOMMEND_EVENTS: User wants event recommendations
            - LIST_CATEGORIES: User asks what categories are available
            - LIST_CITIES: User asks what cities have events
            - EVENT_PRICE_QUERY: User asks about price ranges
            - UPCOMING_EVENTS: User wants to see upcoming events
            - GENERAL_QUERY: Anything else

            Response schema:
            {
              "intent": "SEARCH_EVENTS|RECOMMEND_EVENTS|LIST_CATEGORIES|LIST_CITIES|EVENT_PRICE_QUERY|UPCOMING_EVENTS|GENERAL_QUERY",
              "keyword": "extracted search keyword or null",
              "category": "extracted category name or null",
              "city": "extracted city name or null",
              "limit": 5
            }

            Examples:
            "Show me tech events in Hanoi" → {"intent":"SEARCH_EVENTS","keyword":null,"category":"tech","city":"Hanoi","limit":5}
            "What's happening this weekend?" → {"intent":"UPCOMING_EVENTS","keyword":null,"category":null,"city":null,"limit":5}
            "Recommend something fun" → {"intent":"RECOMMEND_EVENTS","keyword":null,"category":null,"city":null,"limit":5}
            """;

        String response = callGroqApi(systemPrompt, userMessage, 200, 0.2);

        try {
            String cleaned = cleanJsonResponse(response);
            return objectMapper.readValue(cleaned, Map.class);
        } catch (Exception e) {
            log.warn("Failed to parse intent, defaulting to GENERAL_QUERY: {}", e.getMessage());
            Map<String, Object> fallback = new LinkedHashMap<>();
            fallback.put("intent", "GENERAL_QUERY");
            return fallback;
        }
    }

    private Map<String, Object> executeFunction(String intentType, Map<String, Object> intent, User user) {
        Map<String, Object> result = new LinkedHashMap<>();

        switch (intentType) {
            case "SEARCH_EVENTS" -> {
                String keyword = (String) intent.get("keyword");
                String city = (String) intent.get("city");
                Integer limit = intent.get("limit") instanceof Number ? ((Number) intent.get("limit")).intValue() : 5;

                List<Event> events;
                if (keyword != null && !keyword.isBlank()) {
                    events = eventRepository.searchEventsByKeyword(
                            keyword, LocalDateTime.now(), PageRequest.of(0, limit));
                } else if (city != null && !city.isBlank()) {
                    events = cityRepository.findByNameContainingIgnoreCase(city)
                            .stream()
                            .findFirst()
                            .map(c -> eventRepository.findUpcomingEventsByCity(
                                    c, LocalDateTime.now(), LocalDateTime.now().plusMonths(3),
                                    PageRequest.of(0, limit)).getContent())
                            .orElse(List.of());
                } else {
                    events = eventRepository.findUpcomingPublicEvents(
                            LocalDateTime.now(), LocalDateTime.now().plusMonths(3),
                            PageRequest.of(0, limit)).getContent();
                }

                result.put("events", summarizeEvents(events));
                result.put("count", events.size());
            }

            case "UPCOMING_EVENTS" -> {
                Integer limit = intent.get("limit") instanceof Number ? ((Number) intent.get("limit")).intValue() : 5;
                List<Event> events = eventRepository.findUpcomingPublicEvents(
                        LocalDateTime.now(),
                        LocalDateTime.now().plusDays(14),
                        PageRequest.of(0, limit)).getContent();
                result.put("events", summarizeEvents(events));
                result.put("count", events.size());
            }

            case "RECOMMEND_EVENTS" -> {
                Integer limit = intent.get("limit") instanceof Number ? ((Number) intent.get("limit")).intValue() : 5;
                List<Event> events = eventRepository.findUpcomingPublicEvents(
                        LocalDateTime.now(),
                        LocalDateTime.now().plusMonths(2),
                        PageRequest.of(0, limit)).getContent();

                events.sort((a, b) -> Integer.compare(b.getApprovedCount(), a.getApprovedCount()));
                result.put("events", summarizeEvents(events));
                result.put("count", events.size());
                result.put("strategy", "Most popular upcoming events");
            }

            case "LIST_CATEGORIES" -> {
                List<Map<String, Object>> cats = categoryRepository.findAll().stream()
                        .limit(20)
                        .map(c -> {
                            Map<String, Object> m = new LinkedHashMap<>();
                            m.put("name", c.getName());
                            m.put("description", c.getDescription());
                            return m;
                        })
                        .toList();
                result.put("categories", cats);
                result.put("count", cats.size());
            }

            case "LIST_CITIES" -> {
                List<Map<String, Object>> cities = cityRepository.findAll().stream()
                        .limit(20)
                        .map(c -> {
                            Map<String, Object> m = new LinkedHashMap<>();
                            m.put("name", c.getName());
                            m.put("country", c.getCountry());
                            return m;
                        })
                        .toList();
                result.put("cities", cities);
                result.put("count", cities.size());
            }

            case "EVENT_PRICE_QUERY" -> {
                List<Event> events = eventRepository.findUpcomingPublicEvents(
                        LocalDateTime.now(), LocalDateTime.now().plusMonths(3),
                        PageRequest.of(0, 50)).getContent();

                java.math.BigDecimal min = null, max = null, total = java.math.BigDecimal.ZERO;
                int count = 0;
                for (Event e : events) {
                    if (e.getTicketPrice() != null && e.getTicketPrice().compareTo(java.math.BigDecimal.ZERO) > 0) {
                        if (min == null || e.getTicketPrice().compareTo(min) < 0) min = e.getTicketPrice();
                        if (max == null || e.getTicketPrice().compareTo(max) > 0) max = e.getTicketPrice();
                        total = total.add(e.getTicketPrice());
                        count++;
                    }
                }
                result.put("priceRange", Map.of(
                        "min", min != null ? min : 0,
                        "max", max != null ? max : 0,
                        "average", count > 0 ? total.divide(java.math.BigDecimal.valueOf(count), 2, java.math.RoundingMode.HALF_UP) : 0,
                        "samplesAnalyzed", count
                ));
            }

            default -> result.put("info", "No specific data retrieved for this query type.");
        }

        return result;
    }

    private List<Map<String, Object>> summarizeEvents(List<Event> events) {
        DateTimeFormatter dtf = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm");
        List<Map<String, Object>> list = new ArrayList<>();
        for (Event e : events) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", e.getId());
            m.put("title", e.getTitle());
            m.put("startTime", e.getStartTime() != null ? e.getStartTime().format(dtf) : null);
            m.put("venue", e.getVenue());
            m.put("city", e.getCity() != null ? e.getCity().getName() : null);
            m.put("category", e.getCategory() != null ? e.getCategory().getName() : null);
            m.put("price", e.getTicketPrice() != null ? e.getTicketPrice() : 0);
            m.put("approvedAttendees", e.getApprovedCount());
            list.add(m);
        }
        return list;
    }

    private String generateResponse(String userMessage, String intentType, Map<String, Object> data) {
        String systemPrompt = """
            You are LUMA Assistant, a friendly chatbot helping users discover events.

            Rules:
            1. Use ONLY the data provided — never invent events or facts
            2. If data is empty, politely say nothing was found and suggest alternatives
            3. Format event lists with bullets, include title and key info
            4. Detect language from user message (Vietnamese → reply in Vietnamese)
            5. Be concise (under 200 words)
            6. End with a helpful follow-up question if appropriate
            """;

        StringBuilder userPrompt = new StringBuilder();
        userPrompt.append("User asked: \"").append(userMessage).append("\"\n\n");
        userPrompt.append("Intent classified as: ").append(intentType).append("\n\n");
        userPrompt.append("=== DATA RETRIEVED FROM DATABASE ===\n");
        try {
            userPrompt.append(objectMapper.writerWithDefaultPrettyPrinter().writeValueAsString(data));
        } catch (Exception e) {
            userPrompt.append(data.toString());
        }
        userPrompt.append("\n\nGenerate a natural, helpful response based on this data.");

        return callGroqApi(systemPrompt, userPrompt.toString(), 600, 0.7);
    }

    private int countDataPoints(Map<String, Object> data) {
        int count = 0;
        for (Object v : data.values()) {
            if (v instanceof List<?> list) count += list.size();
            else if (v instanceof Number) count++;
        }
        return count;
    }

    private String callGroqApi(String systemPrompt, String userPrompt, int maxTokens, double temperature) {
        try {
            Map<String, Object> requestBody = new LinkedHashMap<>();
            requestBody.put("model", model);
            requestBody.put("max_tokens", maxTokens);
            requestBody.put("temperature", temperature);

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
                log.warn("Groq API returned empty response in assistant");
                return "I'm having trouble processing your request right now.";
            }

            JsonNode responseJson = objectMapper.readTree(responseStr);
            JsonNode choices = responseJson.get("choices");

            if (choices != null && choices.isArray() && choices.size() > 0) {
                JsonNode firstChoice = choices.get(0);
                if (firstChoice == null) return "I'm having trouble processing your request right now.";
                JsonNode message = firstChoice.get("message");
                if (message == null) return "I'm having trouble processing your request right now.";
                JsonNode content = message.get("content");
                if (content == null || content.isNull()) return "I'm having trouble processing your request right now.";
                return content.asText().trim();
            }
            return "I'm having trouble processing your request right now.";
        } catch (Exception e) {
            log.error("Error calling Groq API in assistant: ", e);
            return "Sorry, I encountered an error. Please try again.";
        }
    }

    private String cleanJsonResponse(String response) {
        if (response == null) return "{}";
        String cleaned = response.trim();
        if (cleaned.startsWith("```json")) cleaned = cleaned.substring(7);
        else if (cleaned.startsWith("```")) cleaned = cleaned.substring(3);
        if (cleaned.endsWith("```")) cleaned = cleaned.substring(0, cleaned.length() - 3);
        return cleaned.trim();
    }
}
