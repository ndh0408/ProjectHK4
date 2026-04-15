package com.luma.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.luma.entity.Event;
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

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.*;

@Service
@Slf4j
@RequiredArgsConstructor
public class AISmartPricingService {

    private final RestTemplate groqRestTemplate;
    private final ObjectMapper objectMapper;
    private final EventRepository eventRepository;

    @Value("${groq.model:llama-3.3-70b-versatile}")
    private String model;

    private static final String GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions";

    @org.springframework.transaction.annotation.Transactional(readOnly = true)
    public Map<String, Object> suggestPricing(Long categoryId, Integer capacity, String eventType) {
        if (categoryId == null) {
            throw new IllegalArgumentException("categoryId is required for pricing analysis");
        }

        List<Event> similarEvents = eventRepository.findPaidEventsByCategory(
                categoryId, PageRequest.of(0, 50));

        if (similarEvents.isEmpty()) {
            return defaultPricingSuggestion(capacity, eventType);
        }

        PricingStats stats = calculateStats(similarEvents);

        FillRateAnalysis fillAnalysis = analyzeFillRateByPriceTier(similarEvents);

        String aiReasoning = getAIReasoning(stats, fillAnalysis, capacity, eventType);

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("dataPoints", similarEvents.size());
        result.put("statistics", stats.toMap());
        result.put("fillRateAnalysis", fillAnalysis.toMap());

        Map<String, Object> tiers = new LinkedHashMap<>();
        tiers.put("budget", Map.of(
                "price", stats.p25.setScale(0, RoundingMode.HALF_UP),
                "expectedFillRate", fillAnalysis.lowTierFillRate,
                "strategy", "Maximize attendance, build audience"
        ));
        tiers.put("optimal", Map.of(
                "price", stats.median.setScale(0, RoundingMode.HALF_UP),
                "expectedFillRate", fillAnalysis.midTierFillRate,
                "strategy", "Best balance of revenue and attendance"
        ));
        tiers.put("premium", Map.of(
                "price", stats.p75.setScale(0, RoundingMode.HALF_UP),
                "expectedFillRate", fillAnalysis.highTierFillRate,
                "strategy", "Premium positioning, exclusive feel"
        ));
        result.put("priceTiers", tiers);

        BigDecimal projectedRevenue = stats.median.multiply(
                BigDecimal.valueOf(capacity != null ? capacity : 100))
                .multiply(BigDecimal.valueOf(fillAnalysis.midTierFillRate / 100.0));
        result.put("projectedRevenueAtOptimal", projectedRevenue.setScale(2, RoundingMode.HALF_UP));

        result.put("aiAnalysis", aiReasoning);
        result.put("ragEnabled", true);

        return result;
    }

    private static class PricingStats {
        BigDecimal min;
        BigDecimal max;
        BigDecimal median;
        BigDecimal p25;
        BigDecimal p75;
        BigDecimal average;
        int count;

        Map<String, Object> toMap() {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("count", count);
            m.put("min", min);
            m.put("max", max);
            m.put("median", median);
            m.put("p25", p25);
            m.put("p75", p75);
            m.put("average", average);
            return m;
        }
    }

    private PricingStats calculateStats(List<Event> events) {
        List<BigDecimal> prices = new ArrayList<>();
        for (Event e : events) {
            if (e.getTicketPrice() != null && e.getTicketPrice().compareTo(BigDecimal.ZERO) > 0) {
                prices.add(e.getTicketPrice());
            }
        }
        Collections.sort(prices);

        PricingStats stats = new PricingStats();
        stats.count = prices.size();

        if (prices.isEmpty()) {
            stats.min = stats.max = stats.median = stats.p25 = stats.p75 = stats.average = BigDecimal.ZERO;
            return stats;
        }

        stats.min = prices.get(0);
        stats.max = prices.get(prices.size() - 1);
        stats.median = percentile(prices, 50);
        stats.p25 = percentile(prices, 25);
        stats.p75 = percentile(prices, 75);

        BigDecimal sum = BigDecimal.ZERO;
        for (BigDecimal p : prices) sum = sum.add(p);
        stats.average = sum.divide(BigDecimal.valueOf(prices.size()), 2, RoundingMode.HALF_UP);

        return stats;
    }

    private BigDecimal percentile(List<BigDecimal> sortedList, int percentile) {
        if (sortedList.isEmpty()) return BigDecimal.ZERO;
        int idx = (int) Math.ceil(percentile / 100.0 * sortedList.size()) - 1;
        idx = Math.max(0, Math.min(idx, sortedList.size() - 1));
        return sortedList.get(idx);
    }

    private static class FillRateAnalysis {
        double lowTierFillRate;
        double midTierFillRate;
        double highTierFillRate;
        double overallAverageFillRate;
        String correlation;

        Map<String, Object> toMap() {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("lowTierFillRate", Math.round(lowTierFillRate * 10) / 10.0);
            m.put("midTierFillRate", Math.round(midTierFillRate * 10) / 10.0);
            m.put("highTierFillRate", Math.round(highTierFillRate * 10) / 10.0);
            m.put("overallAverage", Math.round(overallAverageFillRate * 10) / 10.0);
            m.put("priceFillCorrelation", correlation);
            return m;
        }
    }

    private FillRateAnalysis analyzeFillRateByPriceTier(List<Event> events) {
        FillRateAnalysis result = new FillRateAnalysis();

        List<Event> validEvents = new ArrayList<>();
        for (Event e : events) {
            if (e.getCapacity() != null && e.getCapacity() > 0
                    && e.getTicketPrice() != null && e.getTicketPrice().compareTo(BigDecimal.ZERO) > 0) {
                validEvents.add(e);
            }
        }

        if (validEvents.isEmpty()) {
            result.lowTierFillRate = result.midTierFillRate = result.highTierFillRate = 0;
            result.overallAverageFillRate = 0;
            result.correlation = "INSUFFICIENT_DATA";
            return result;
        }

        validEvents.sort(Comparator.comparing(Event::getTicketPrice));
        int third = validEvents.size() / 3;

        result.lowTierFillRate = avgFillRate(validEvents.subList(0, Math.max(1, third)));
        result.midTierFillRate = avgFillRate(validEvents.subList(third, Math.min(validEvents.size(), 2 * third + 1)));
        result.highTierFillRate = avgFillRate(validEvents.subList(Math.max(0, 2 * third), validEvents.size()));
        result.overallAverageFillRate = avgFillRate(validEvents);

        if (result.lowTierFillRate > result.highTierFillRate + 15) {
            result.correlation = "STRONG_NEGATIVE";
        } else if (result.lowTierFillRate > result.highTierFillRate + 5) {
            result.correlation = "WEAK_NEGATIVE";
        } else if (result.highTierFillRate > result.lowTierFillRate + 10) {
            result.correlation = "POSITIVE";
        } else {
            result.correlation = "NEUTRAL";
        }

        return result;
    }

    private double avgFillRate(List<Event> events) {
        if (events.isEmpty()) return 0;
        double total = 0;
        int count = 0;
        for (Event e : events) {
            if (e.getCapacity() != null && e.getCapacity() > 0) {
                total += (double) e.getApprovedCount() / e.getCapacity() * 100;
                count++;
            }
        }
        return count > 0 ? total / count : 0;
    }

    private String getAIReasoning(PricingStats stats, FillRateAnalysis fill, Integer capacity, String eventType) {
        String systemPrompt = """
            You are a pricing strategy expert for event marketplaces.
            You will receive REAL data from the platform's database analyzing similar events.
            Your job is to provide a concise pricing recommendation with reasoning.

            Rules:
            1. Reference the actual numbers in the data
            2. Be 2-3 sentences only
            3. Plain text, no markdown
            4. If correlation is STRONG_NEGATIVE, warn about overpricing
            5. If POSITIVE, suggest premium positioning is viable
            """;

        StringBuilder userPrompt = new StringBuilder();
        userPrompt.append("Analyze pricing for a new event:\n");
        userPrompt.append("- Event type: ").append(eventType != null ? eventType : "general").append("\n");
        userPrompt.append("- Planned capacity: ").append(capacity != null ? capacity : "unspecified").append("\n\n");

        userPrompt.append("=== DATA FROM ").append(stats.count).append(" SIMILAR PAID EVENTS ===\n");
        userPrompt.append("Price range: $").append(stats.min).append(" - $").append(stats.max).append("\n");
        userPrompt.append("Median: $").append(stats.median).append("\n");
        userPrompt.append("25th percentile: $").append(stats.p25).append("\n");
        userPrompt.append("75th percentile: $").append(stats.p75).append("\n");
        userPrompt.append("Average: $").append(stats.average).append("\n\n");

        userPrompt.append("=== FILL RATE BY PRICE TIER ===\n");
        userPrompt.append("Low-priced events: ").append(Math.round(fill.lowTierFillRate)).append("% fill\n");
        userPrompt.append("Mid-priced events: ").append(Math.round(fill.midTierFillRate)).append("% fill\n");
        userPrompt.append("High-priced events: ").append(Math.round(fill.highTierFillRate)).append("% fill\n");
        userPrompt.append("Price-fill correlation: ").append(fill.correlation).append("\n");

        return callGroqApi(systemPrompt, userPrompt.toString(), 250);
    }

    private Map<String, Object> defaultPricingSuggestion(Integer capacity, String eventType) {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("dataPoints", 0);
        result.put("ragEnabled", false);
        result.put("message", "No historical data available for this category. Suggesting defaults based on event type.");

        BigDecimal defaultPrice = switch (eventType != null ? eventType.toLowerCase() : "") {
            case "workshop" -> BigDecimal.valueOf(50);
            case "conference" -> BigDecimal.valueOf(150);
            case "meetup" -> BigDecimal.valueOf(15);
            case "concert" -> BigDecimal.valueOf(80);
            case "seminar" -> BigDecimal.valueOf(40);
            default -> BigDecimal.valueOf(30);
        };

        result.put("suggestedPrice", defaultPrice);
        return result;
    }

    private String callGroqApi(String systemPrompt, String userPrompt, int maxTokens) {
        try {
            Map<String, Object> requestBody = new LinkedHashMap<>();
            requestBody.put("model", model);
            requestBody.put("max_tokens", maxTokens);
            requestBody.put("temperature", 0.5);

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
                log.warn("Groq API returned empty response for pricing");
                return "AI analysis temporarily unavailable.";
            }

            JsonNode responseJson = objectMapper.readTree(responseStr);
            JsonNode choices = responseJson.get("choices");

            if (choices != null && choices.isArray() && choices.size() > 0) {
                JsonNode firstChoice = choices.get(0);
                if (firstChoice == null) return "Unable to generate analysis.";
                JsonNode message = firstChoice.get("message");
                if (message == null) return "Unable to generate analysis.";
                JsonNode content = message.get("content");
                if (content == null || content.isNull()) return "Unable to generate analysis.";
                return content.asText().trim();
            }
            return "Unable to generate analysis.";
        } catch (Exception e) {
            log.error("Error calling Groq API for pricing: ", e);
            return "AI analysis temporarily unavailable.";
        }
    }
}
