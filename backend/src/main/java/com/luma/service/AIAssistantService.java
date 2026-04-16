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

    @Value("${groq.api-key:}")
    private String apiKey;

    private static final String GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions";

    @org.springframework.transaction.annotation.Transactional(readOnly = true)
    public Map<String, Object> chat(String userMessage, User user, List<Map<String, String>> conversationHistory) {
        // Check if API key is configured
        if (apiKey == null || apiKey.isBlank()) {
            log.warn("Groq API key not configured, using database-only mode");
            return chatWithoutAI(userMessage, user);
        }

        try {
            Map<String, Object> intent = detectIntent(userMessage);
            String intentType = (String) intent.getOrDefault("intent", "GENERAL_QUERY");
            log.info("AI Assistant detected intent: {} for user {}", intentType, user != null ? user.getId() : "anonymous");

            // Block off-topic and general queries immediately — do NOT let AI answer them
            if ("OFF_TOPIC".equals(intentType) || "GENERAL_QUERY".equals(intentType)) {
                String lowerMsg = userMessage.toLowerCase().replaceAll("[^a-z\\s]", "").trim();
                if (_isGreeting(lowerMsg)) {
                    intentType = "GREETING";
                }
            }

            if ("OFF_TOPIC".equals(intentType) || "GENERAL_QUERY".equals(intentType)) {
                Map<String, Object> result = new LinkedHashMap<>();
                result.put("response", OFF_TOPIC_RESPONSE);
                result.put("intent", "OFF_TOPIC");
                result.put("data", Map.of());
                result.put("dataPointsUsed", 0);
                return result;
            }

            if ("GREETING".equals(intentType)) {
                Map<String, Object> result = new LinkedHashMap<>();
                result.put("response", GREETING_RESPONSE);
                result.put("intent", "GREETING");
                result.put("data", Map.of());
                result.put("dataPointsUsed", 0);
                return result;
            }

            Map<String, Object> retrievedData = executeFunction(intentType, intent, user);
            String naturalResponse = generateResponse(userMessage, intentType, retrievedData, conversationHistory);

            Map<String, Object> result = new LinkedHashMap<>();
            result.put("response", naturalResponse);
            result.put("intent", intentType);
            result.put("data", retrievedData);
            result.put("dataPointsUsed", countDataPoints(retrievedData));
            return result;
        } catch (Exception e) {
            log.error("AI chat failed, falling back to database-only mode: {}", e.getMessage());
            return chatWithoutAI(userMessage, user);
        }
    }

    // Backward compatibility
    @org.springframework.transaction.annotation.Transactional(readOnly = true)
    public Map<String, Object> chat(String userMessage, User user) {
        return chat(userMessage, user, null);
    }

    /**
     * Fallback mode when Groq API is unavailable - uses database queries directly
     */
    private static final String OFF_TOPIC_RESPONSE =
            "I'm **LUMA Assistant** and I specialize in helping you discover events! 🎉\n\n" +
            "I can't help with that topic, but I'd love to help you find amazing events. Here's what I can do:\n\n" +
            "• 🔍 **Search events** by keyword, category, or city\n" +
            "• 🌟 **Recommend** popular and trending events\n" +
            "• 📅 **Show upcoming** events this week\n" +
            "• 📂 **List categories** and cities available\n" +
            "• 💰 **Check prices** and find free events\n\n" +
            "Try asking me something like: \"Show me tech events\" or \"What's happening this weekend?\"";

    private static final String GREETING_RESPONSE =
            "Hi there! 👋 I'm **LUMA Assistant**, your AI-powered event discovery helper!\n\n" +
            "I can help you with:\n" +
            "• 🔍 Finding events by keyword, category, or city\n" +
            "• 🌟 Recommending popular events\n" +
            "• 📅 Showing upcoming events\n" +
            "• 💰 Checking event prices\n\n" +
            "What kind of events are you looking for?";

    private Map<String, Object> chatWithoutAI(String userMessage, User user) {
        String lowerMsg = userMessage.toLowerCase();
        Map<String, Object> result = new LinkedHashMap<>();
        Map<String, Object> data = new LinkedHashMap<>();
        String intentType;
        String response;

        // Check for greetings first
        if (_isGreeting(lowerMsg)) {
            intentType = "GREETING";
            response = GREETING_RESPONSE;
            result.put("response", response);
            result.put("intent", intentType);
            result.put("data", data);
            result.put("dataPointsUsed", 0);
            return result;
        }

        if (lowerMsg.contains("category") || lowerMsg.contains("categories") || lowerMsg.contains("thể loại")) {
            intentType = "LIST_CATEGORIES";
            List<Map<String, Object>> cats = categoryRepository.findAll().stream()
                    .limit(20)
                    .map(c -> {
                        Map<String, Object> m = new LinkedHashMap<>();
                        m.put("name", c.getName());
                        m.put("description", c.getDescription());
                        return m;
                    })
                    .toList();
            data.put("categories", cats);
            data.put("count", cats.size());
            response = formatCategoriesResponse(cats);

        } else if (lowerMsg.contains("city") || lowerMsg.contains("cities") || lowerMsg.contains("thành phố")) {
            intentType = "LIST_CITIES";
            List<Map<String, Object>> cities = cityRepository.findAll().stream()
                    .limit(20)
                    .map(c -> {
                        Map<String, Object> m = new LinkedHashMap<>();
                        m.put("name", c.getName());
                        m.put("country", c.getCountry());
                        return m;
                    })
                    .toList();
            data.put("cities", cities);
            data.put("count", cities.size());
            response = formatCitiesResponse(cities);

        } else if (lowerMsg.contains("recommend") || lowerMsg.contains("suggest") || lowerMsg.contains("fun")
                || lowerMsg.contains("popular") || lowerMsg.contains("trending")) {
            intentType = "RECOMMEND_EVENTS";
            List<Event> events = eventRepository.findUpcomingPublicEvents(
                    LocalDateTime.now(), LocalDateTime.now().plusMonths(2),
                    PageRequest.of(0, 5)).getContent();
            events.sort((a, b) -> Integer.compare(b.getApprovedCount(), a.getApprovedCount()));
            data.put("events", summarizeEvents(events));
            data.put("count", events.size());
            response = formatEventsResponse("Here are some popular events I'd recommend:", events);

        } else if (lowerMsg.contains("upcoming") || lowerMsg.contains("weekend") || lowerMsg.contains("soon")
                || lowerMsg.contains("happening") || lowerMsg.contains("this week")) {
            intentType = "UPCOMING_EVENTS";
            List<Event> events = eventRepository.findUpcomingPublicEvents(
                    LocalDateTime.now(), LocalDateTime.now().plusDays(14),
                    PageRequest.of(0, 5)).getContent();
            data.put("events", summarizeEvents(events));
            data.put("count", events.size());
            response = formatEventsResponse("Here are upcoming events:", events);

        } else if (lowerMsg.contains("price") || lowerMsg.contains("cost") || lowerMsg.contains("free")
                || lowerMsg.contains("cheap") || lowerMsg.contains("giá")) {
            intentType = "EVENT_PRICE_QUERY";
            List<Event> events = eventRepository.findUpcomingPublicEvents(
                    LocalDateTime.now(), LocalDateTime.now().plusMonths(3),
                    PageRequest.of(0, 50)).getContent();

            java.math.BigDecimal min = null, max = null, total = java.math.BigDecimal.ZERO;
            int count = 0;
            int freeCount = 0;
            for (Event e : events) {
                if (e.getTicketPrice() == null || e.getTicketPrice().compareTo(java.math.BigDecimal.ZERO) == 0) {
                    freeCount++;
                } else {
                    if (min == null || e.getTicketPrice().compareTo(min) < 0) min = e.getTicketPrice();
                    if (max == null || e.getTicketPrice().compareTo(max) > 0) max = e.getTicketPrice();
                    total = total.add(e.getTicketPrice());
                    count++;
                }
            }
            data.put("priceRange", Map.of(
                    "min", min != null ? min : 0,
                    "max", max != null ? max : 0,
                    "average", count > 0 ? total.divide(java.math.BigDecimal.valueOf(count), 2, java.math.RoundingMode.HALF_UP) : 0,
                    "samplesAnalyzed", count,
                    "freeEvents", freeCount
            ));
            response = String.format("📊 **Price Overview**\n\n" +
                    "• Free events: %d\n• Paid events: %d\n• Price range: $%s - $%s\n• Average price: $%s\n\n" +
                    "Would you like to see specific free or paid events?",
                    freeCount, count,
                    min != null ? min.toPlainString() : "0",
                    max != null ? max.toPlainString() : "0",
                    count > 0 ? total.divide(java.math.BigDecimal.valueOf(count), 2, java.math.RoundingMode.HALF_UP).toPlainString() : "0");

        } else if (_isEventRelated(lowerMsg)) {
            // Search events by keyword
            intentType = "SEARCH_EVENTS";
            List<Event> events;
            try {
                events = eventRepository.searchEventsByKeyword(
                        userMessage, LocalDateTime.now(), PageRequest.of(0, 5));
            } catch (Exception e) {
                events = eventRepository.findUpcomingPublicEvents(
                        LocalDateTime.now(), LocalDateTime.now().plusMonths(1),
                        PageRequest.of(0, 5)).getContent();
            }

            if (events.isEmpty()) {
                events = eventRepository.findUpcomingPublicEvents(
                        LocalDateTime.now(), LocalDateTime.now().plusMonths(1),
                        PageRequest.of(0, 5)).getContent();
                response = "I couldn't find events matching your query, but here are some upcoming events you might like:";
            } else {
                response = "Here's what I found:";
            }
            data.put("events", summarizeEvents(events));
            data.put("count", events.size());
            response = formatEventsResponse(response, events);
        } else {
            // Off-topic question
            intentType = "OFF_TOPIC";
            response = OFF_TOPIC_RESPONSE;
        }

        result.put("response", response);
        result.put("intent", intentType);
        result.put("data", data);
        result.put("dataPointsUsed", countDataPoints(data));
        return result;
    }

    private String formatEventsResponse(String header, List<Event> events) {
        if (events.isEmpty()) {
            return "No events found at the moment. Try checking back later or explore different categories!";
        }
        DateTimeFormatter dtf = DateTimeFormatter.ofPattern("MMM dd, yyyy");
        StringBuilder sb = new StringBuilder(header).append("\n\n");
        for (Event e : events) {
            sb.append("• **").append(e.getTitle()).append("**");
            if (e.getStartTime() != null) sb.append(" — ").append(e.getStartTime().format(dtf));
            if (e.getCity() != null) sb.append(" 📍 ").append(e.getCity().getName());
            if (e.getTicketPrice() != null && e.getTicketPrice().compareTo(java.math.BigDecimal.ZERO) > 0) {
                sb.append(" 💰 $").append(e.getTicketPrice().toPlainString());
            } else {
                sb.append(" 🆓 Free");
            }
            sb.append("\n");
        }
        sb.append("\nWould you like more details about any of these events?");
        return sb.toString();
    }

    private String formatCategoriesResponse(List<Map<String, Object>> cats) {
        StringBuilder sb = new StringBuilder("📂 **Available Categories:**\n\n");
        for (Map<String, Object> c : cats) {
            sb.append("• **").append(c.get("name")).append("**");
            if (c.get("description") != null) sb.append(" — ").append(c.get("description"));
            sb.append("\n");
        }
        sb.append("\nWould you like to see events in a specific category?");
        return sb.toString();
    }

    private String formatCitiesResponse(List<Map<String, Object>> cities) {
        StringBuilder sb = new StringBuilder("🌍 **Available Cities:**\n\n");
        for (Map<String, Object> c : cities) {
            sb.append("• **").append(c.get("name")).append("**");
            if (c.get("country") != null) sb.append(" (").append(c.get("country")).append(")");
            sb.append("\n");
        }
        sb.append("\nWould you like to see events in a specific city?");
        return sb.toString();
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
            - GREETING: User says hello, hi, thanks, or introduces themselves
            - OFF_TOPIC: User asks about something NOT related to events (e.g. math, coding, weather, politics, general knowledge, personal advice)

            Response schema:
            {
              "intent": "SEARCH_EVENTS|RECOMMEND_EVENTS|LIST_CATEGORIES|LIST_CITIES|EVENT_PRICE_QUERY|UPCOMING_EVENTS|GREETING|OFF_TOPIC",
              "keyword": "extracted search keyword or null",
              "category": "extracted category name or null",
              "city": "extracted city name or null",
              "limit": 5
            }

            Examples:
            "Show me tech events in Hanoi" → {"intent":"SEARCH_EVENTS","keyword":null,"category":"tech","city":"Hanoi","limit":5}
            "What's happening this weekend?" → {"intent":"UPCOMING_EVENTS","keyword":null,"category":null,"city":null,"limit":5}
            "Recommend something fun" → {"intent":"RECOMMEND_EVENTS","keyword":null,"category":null,"city":null,"limit":5}
            "Hi there" → {"intent":"GREETING","keyword":null,"category":null,"city":null,"limit":5}
            "What is 2+2?" → {"intent":"OFF_TOPIC","keyword":null,"category":null,"city":null,"limit":5}
            "Tell me about Python programming" → {"intent":"OFF_TOPIC","keyword":null,"category":null,"city":null,"limit":5}
            "What's the weather today?" → {"intent":"OFF_TOPIC","keyword":null,"category":null,"city":null,"limit":5}
            """;

        String response = callGroqApi(systemPrompt, userMessage, 200, 0.2, null);

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
                String category = (String) intent.get("category");
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
                } else if (category != null && !category.isBlank()) {
                    // Search by category name
                    events = categoryRepository.findByNameContainingIgnoreCase(category)
                            .stream()
                            .findFirst()
                            .map(c -> eventRepository.findUpcomingEventsByCategory(
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

            case "GREETING" -> {
                result.put("info", "greeting");
            }

            case "OFF_TOPIC" -> {
                result.put("info", "off_topic");
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
            m.put("imageUrl", e.getImageUrl());
            list.add(m);
        }
        return list;
    }

    private String generateResponse(String userMessage, String intentType, Map<String, Object> data,
                                     List<Map<String, String>> conversationHistory) {
        String systemPrompt = """
            You are LUMA Assistant, an AI chatbot that ONLY helps users discover and explore events on the LUMA event marketplace platform.

            STRICT SCOPE — You can ONLY help with:
            - Finding, searching, and recommending events
            - Event categories, cities, prices, dates, venues
            - Answering questions about events on the platform

            IMPORTANT RULES:
            1. Use ONLY the data provided — never invent events, prices, or facts
            2. If data is empty, politely say nothing was found and suggest event-related alternatives
            3. Format event lists clearly with bullets, include title, date, location, and price
            4. Always respond in English, regardless of the language of the user message
            5. Be concise but helpful (under 250 words)
            6. Use markdown formatting: **bold** for event names, bullet points for lists
            7. End with a helpful follow-up question about events when appropriate
            8. For greetings, be friendly and briefly explain what you can help with (event discovery only)
            9. If the intent is OFF_TOPIC, you MUST politely decline and redirect to event topics. Say something like: "I'm LUMA Assistant and I specialize in helping you discover events! I can't help with that topic, but I'd love to help you find amazing events. Try asking me about upcoming events, event categories, or events in your city!"
            10. NEVER answer questions about: math, science, coding, weather, politics, personal advice, general knowledge, or anything unrelated to events
            """;

        List<Map<String, String>> messages = new ArrayList<>();

        // Add system message
        Map<String, String> systemMessage = new LinkedHashMap<>();
        systemMessage.put("role", "system");
        systemMessage.put("content", systemPrompt);
        messages.add(systemMessage);

        // Add conversation history for context (last 6 messages)
        if (conversationHistory != null && !conversationHistory.isEmpty()) {
            int start = Math.max(0, conversationHistory.size() - 6);
            for (int i = start; i < conversationHistory.size(); i++) {
                messages.add(conversationHistory.get(i));
            }
        }

        // Build current user prompt with retrieved data
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

        Map<String, String> userMsg = new LinkedHashMap<>();
        userMsg.put("role", "user");
        userMsg.put("content", userPrompt.toString());
        messages.add(userMsg);

        return callGroqApiWithMessages(messages, 600, 0.7);
    }

    private int countDataPoints(Map<String, Object> data) {
        int count = 0;
        for (Object v : data.values()) {
            if (v instanceof List<?> list) count += list.size();
            else if (v instanceof Number) count++;
        }
        return count;
    }

    private String callGroqApi(String systemPrompt, String userPrompt, int maxTokens, double temperature,
                                List<Map<String, String>> extraMessages) {
        List<Map<String, String>> messages = new ArrayList<>();

        Map<String, String> systemMessage = new LinkedHashMap<>();
        systemMessage.put("role", "system");
        systemMessage.put("content", systemPrompt);
        messages.add(systemMessage);

        if (extraMessages != null) {
            messages.addAll(extraMessages);
        }

        Map<String, String> userMessage = new LinkedHashMap<>();
        userMessage.put("role", "user");
        userMessage.put("content", userPrompt);
        messages.add(userMessage);

        return callGroqApiWithMessages(messages, maxTokens, temperature);
    }

    private String callGroqApiWithMessages(List<Map<String, String>> messages, int maxTokens, double temperature) {
        try {
            Map<String, Object> requestBody = new LinkedHashMap<>();
            requestBody.put("model", model);
            requestBody.put("max_tokens", maxTokens);
            requestBody.put("temperature", temperature);
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

            if (choices != null && choices.isArray() && !choices.isEmpty()) {
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
            throw new RuntimeException("Groq API call failed: " + e.getMessage(), e);
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

    private boolean _isGreeting(String lowerMsg) {
        String trimmed = lowerMsg.replaceAll("[^a-z\\s]", "").trim();
        List<String> greetings = List.of(
                "hi", "hello", "hey", "good morning", "good afternoon", "good evening",
                "thanks", "thank you", "bye", "goodbye", "xin chao", "chao",
                "cam on", "how are you", "whats up", "sup"
        );
        for (String g : greetings) {
            if (trimmed.equals(g) || trimmed.startsWith(g + " ")) return true;
        }
        return false;
    }

    private boolean _isEventRelated(String lowerMsg) {
        List<String> eventKeywords = List.of(
                "event", "events", "concert", "workshop", "seminar", "conference",
                "meetup", "party", "festival", "show", "exhibition", "performance",
                "ticket", "register", "attend", "venue", "schedule", "date",
                "music", "art", "sport", "tech", "food", "travel", "business",
                "networking", "hackathon", "webinar", "training", "class",
                "sự kiện", "hội thảo", "buổi", "vé", "đăng ký"
        );
        for (String keyword : eventKeywords) {
            if (lowerMsg.contains(keyword)) return true;
        }
        return false;
    }
}
