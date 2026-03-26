package com.luma.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.luma.entity.Event;
import com.luma.entity.Question;
import com.luma.entity.User;
import com.luma.entity.enums.EventStatus;
import com.luma.entity.enums.RegistrationStatus;
import com.luma.repository.*;
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
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

/**
 * AI Service với khả năng query database để cung cấp context thông minh hơn
 * Kết hợp: Database Query + AI Generation
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class AIQueryService {

    private final RestTemplate groqRestTemplate;
    private final ObjectMapper objectMapper;
    private final QuestionRepository questionRepository;
    private final EventRepository eventRepository;
    private final RegistrationRepository registrationRepository;
    private final ReviewRepository reviewRepository;
    private final FollowRepository followRepository;
    private final PayoutRepository payoutRepository;

    @Value("${groq.model:llama-3.3-70b-versatile}")
    private String model;

    private static final String GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions";

    // ==================== AI + Database: Smart Answer Suggestion ====================

    /**
     * Gợi ý câu trả lời thông minh dựa trên:
     * 1. Các câu hỏi tương tự đã được trả lời (FAQ)
     * 2. Thông tin sự kiện
     * 3. Lịch sử trả lời của organiser
     */
    public Map<String, Object> suggestAnswerWithContext(Question question) {
        Event event = question.getEvent();
        User organiser = event.getOrganiser();

        // 1. Query database: Tìm câu hỏi tương tự đã được trả lời
        List<Question> similarQuestions = findSimilarAnsweredQuestions(question);

        // 2. Query: Các câu hỏi đã trả lời trong cùng sự kiện
        List<Question> eventFAQs = questionRepository.findAnsweredByEvent(event);

        // 3. Query: Lịch sử trả lời của organiser (để học style)
        List<Question> organiserHistory = questionRepository.findAnsweredHistoryByOrganiser(
                organiser, PageRequest.of(0, 10)).getContent();

        // Build context từ database
        StringBuilder dbContext = new StringBuilder();

        if (!similarQuestions.isEmpty()) {
            dbContext.append("\n=== SIMILAR QUESTIONS ALREADY ANSWERED (FAQ) ===\n");
            for (Question sq : similarQuestions) {
                dbContext.append("Q: ").append(sq.getQuestion()).append("\n");
                dbContext.append("A: ").append(sq.getAnswer()).append("\n\n");
            }
        }

        if (!eventFAQs.isEmpty() && eventFAQs.size() > similarQuestions.size()) {
            dbContext.append("\n=== OTHER FAQs FOR THIS EVENT ===\n");
            int count = 0;
            for (Question faq : eventFAQs) {
                if (count >= 5) break;
                if (!similarQuestions.contains(faq)) {
                    dbContext.append("Q: ").append(faq.getQuestion()).append("\n");
                    dbContext.append("A: ").append(faq.getAnswer()).append("\n\n");
                    count++;
                }
            }
        }

        // Build AI prompt với database context
        String systemPrompt = buildSmartAnswerSystemPrompt(event, dbContext.toString());
        String userPrompt = buildSmartAnswerUserPrompt(question);

        try {
            String aiResponse = callGroqApi(systemPrompt, userPrompt, 600);

            Map<String, Object> result = new HashMap<>();
            result.put("suggestedAnswer", aiResponse);
            result.put("similarQuestionsFound", similarQuestions.size());
            result.put("eventFAQsCount", eventFAQs.size());
            result.put("contextUsed", !similarQuestions.isEmpty() || !eventFAQs.isEmpty());

            // Thêm danh sách câu hỏi tương tự để hiển thị
            if (!similarQuestions.isEmpty()) {
                List<Map<String, String>> similarList = similarQuestions.stream()
                        .limit(3)
                        .map(sq -> Map.of(
                                "question", sq.getQuestion(),
                                "answer", sq.getAnswer() != null ? sq.getAnswer() : ""
                        ))
                        .collect(Collectors.toList());
                result.put("similarQuestions", similarList);
            }

            return result;
        } catch (Exception e) {
            log.error("Error generating smart answer: ", e);
            throw new RuntimeException("Failed to generate AI suggestion: " + e.getMessage());
        }
    }

    private List<Question> findSimilarAnsweredQuestions(Question question) {
        String questionText = question.getQuestion().toLowerCase();

        // Extract keywords từ câu hỏi
        List<String> keywords = extractKeywords(questionText);

        Set<Question> similarQuestions = new LinkedHashSet<>();

        for (String keyword : keywords) {
            if (keyword.length() >= 3) {
                List<Question> found = questionRepository.findSimilarAnsweredQuestions(
                        keyword, PageRequest.of(0, 5));
                similarQuestions.addAll(found);
            }
            if (similarQuestions.size() >= 5) break;
        }

        // Loại bỏ câu hỏi hiện tại (nếu có)
        similarQuestions.removeIf(q -> q.getId().equals(question.getId()));

        return new ArrayList<>(similarQuestions).subList(0, Math.min(5, similarQuestions.size()));
    }

    private List<String> extractKeywords(String text) {
        // Loại bỏ stop words tiếng Việt và tiếng Anh
        Set<String> stopWords = Set.of(
                "là", "và", "của", "cho", "có", "được", "này", "đó", "các", "một", "những",
                "tôi", "bạn", "chúng", "họ", "nó", "em", "anh", "chị",
                "the", "a", "an", "is", "are", "was", "were", "be", "been", "being",
                "have", "has", "had", "do", "does", "did", "will", "would", "could", "should",
                "what", "when", "where", "who", "how", "why", "which",
                "không", "như", "thế", "nào", "sao", "gì", "bao", "nhiêu", "khi", "ở", "đâu"
        );

        return Arrays.stream(text.split("\\s+"))
                .map(String::toLowerCase)
                .map(word -> word.replaceAll("[^a-zA-Zàáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ]", ""))
                .filter(word -> word.length() >= 3 && !stopWords.contains(word))
                .distinct()
                .limit(5)
                .collect(Collectors.toList());
    }

    private String buildSmartAnswerSystemPrompt(Event event, String dbContext) {
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");

        StringBuilder sb = new StringBuilder();
        sb.append("You are an AI assistant helping event organizers answer attendee questions.\n\n");
        sb.append("CRITICAL RULES:\n");
        sb.append("1. If similar questions have been answered before (shown in FAQ section), use those answers as reference\n");
        sb.append("2. Maintain consistency with previous answers\n");
        sb.append("3. Match the language of the question (Vietnamese or English)\n");
        sb.append("4. Keep answers concise and helpful\n\n");

        sb.append("=== EVENT INFORMATION ===\n");
        sb.append("Title: ").append(event.getTitle()).append("\n");
        if (event.getDescription() != null) {
            sb.append("Description: ").append(truncate(event.getDescription(), 500)).append("\n");
        }
        if (event.getStartTime() != null) {
            sb.append("Start: ").append(event.getStartTime().format(formatter)).append("\n");
        }
        if (event.getEndTime() != null) {
            sb.append("End: ").append(event.getEndTime().format(formatter)).append("\n");
        }
        if (event.getVenue() != null) {
            sb.append("Venue: ").append(event.getVenue()).append("\n");
        }
        if (event.getAddress() != null) {
            sb.append("Address: ").append(event.getAddress()).append("\n");
        }
        if (event.getTicketPrice() != null && event.getTicketPrice().doubleValue() > 0) {
            sb.append("Price: ").append(event.getTicketPrice()).append(" VND\n");
        }

        // Thêm database context (FAQ)
        if (!dbContext.isEmpty()) {
            sb.append("\n").append(dbContext);
            sb.append("\nIMPORTANT: Use the above FAQ answers as reference. Be consistent with previous responses.\n");
        }

        return sb.toString();
    }

    private String buildSmartAnswerUserPrompt(Question question) {
        String questionText = question.getQuestion();
        boolean isVietnamese = questionText.matches(".*[àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđĐ].*");

        return "Question from attendee:\n" + questionText + "\n\n" +
               (isVietnamese ? "Trả lời bằng tiếng Việt." : "Answer in English.");
    }

    // ==================== AI + Database: Smart Dashboard Insights ====================

    /**
     * Tạo insights thông minh cho Organiser Dashboard dựa trên:
     * 1. Thống kê sự kiện và đăng ký từ DB
     * 2. So sánh với các organiser khác (benchmarking)
     * 3. Phân tích xu hướng
     */
    public Map<String, Object> generateSmartOrganiserInsights(User organiser) {
        // Query database để lấy đầy đủ context
        Map<String, Object> dbStats = gatherOrganiserStats(organiser);
        Map<String, Object> benchmarks = gatherBenchmarks(organiser);

        // Build AI prompt với database context
        String systemPrompt = buildOrganiserInsightsSystemPrompt();
        String userPrompt = buildOrganiserInsightsUserPrompt(dbStats, benchmarks);

        try {
            String aiResponse = callGroqApi(systemPrompt, userPrompt, 1200);
            String cleanJson = cleanJsonResponse(aiResponse);

            Map<String, Object> insights = objectMapper.readValue(cleanJson, Map.class);

            // Thêm raw stats cho frontend
            insights.put("rawStats", dbStats);
            insights.put("benchmarks", benchmarks);

            return insights;
        } catch (Exception e) {
            log.error("Error generating organiser insights: ", e);
            return createFallbackInsights(dbStats);
        }
    }

    private Map<String, Object> gatherOrganiserStats(User organiser) {
        Map<String, Object> stats = new LinkedHashMap<>();

        // Event stats
        long totalEvents = eventRepository.countByOrganiser(organiser);
        long publishedEvents = eventRepository.countByOrganiserAndStatus(organiser, EventStatus.PUBLISHED);
        long completedEvents = eventRepository.countByOrganiserAndStatus(organiser, EventStatus.COMPLETED);
        long draftEvents = eventRepository.countByOrganiserAndStatus(organiser, EventStatus.DRAFT);

        stats.put("totalEvents", totalEvents);
        stats.put("publishedEvents", publishedEvents);
        stats.put("completedEvents", completedEvents);
        stats.put("draftEvents", draftEvents);

        // Registration stats
        long totalRegistrations = registrationRepository.countAllByOrganiser(organiser);
        long approvedRegistrations = registrationRepository.countByOrganiserAndStatus(organiser, RegistrationStatus.APPROVED);
        long pendingRegistrations = registrationRepository.countByOrganiserAndStatus(organiser, RegistrationStatus.PENDING);

        stats.put("totalRegistrations", totalRegistrations);
        stats.put("approvedRegistrations", approvedRegistrations);
        stats.put("pendingRegistrations", pendingRegistrations);

        // Calculate approval rate
        double approvalRate = totalRegistrations > 0
                ? (double) approvedRegistrations / totalRegistrations * 100
                : 0;
        stats.put("approvalRate", Math.round(approvalRate * 10) / 10.0);

        // Followers
        long followers = followRepository.countByOrganiser(organiser);
        stats.put("followers", followers);

        // Revenue
        BigDecimal revenue = registrationRepository.calculateTotalRevenueByOrganiser(organiser);
        stats.put("totalRevenue", revenue != null ? revenue : BigDecimal.ZERO);

        // Question stats
        long totalQuestions = questionRepository.countByOrganiser(organiser);
        long unansweredQuestions = questionRepository.countUnansweredByOrganiser(organiser);
        stats.put("totalQuestions", totalQuestions);
        stats.put("unansweredQuestions", unansweredQuestions);

        // Response rate
        double responseRate = totalQuestions > 0
                ? (double) (totalQuestions - unansweredQuestions) / totalQuestions * 100
                : 100;
        stats.put("questionResponseRate", Math.round(responseRate * 10) / 10.0);

        // Recent events performance
        List<Event> recentEvents = eventRepository.findByOrganiserOrderByCreatedAtDesc(
                organiser, PageRequest.of(0, 5)).getContent();
        List<Map<String, Object>> recentPerformance = new ArrayList<>();
        for (Event event : recentEvents) {
            Map<String, Object> ep = new LinkedHashMap<>();
            ep.put("title", event.getTitle());
            ep.put("status", event.getStatus().name());
            ep.put("registrations", event.getApprovedCount());
            ep.put("capacity", event.getCapacity());
            if (event.getCapacity() != null && event.getCapacity() > 0) {
                ep.put("fillRate", Math.round((double) event.getApprovedCount() / event.getCapacity() * 100));
            }
            recentPerformance.add(ep);
        }
        stats.put("recentEvents", recentPerformance);

        return stats;
    }

    private Map<String, Object> gatherBenchmarks(User organiser) {
        Map<String, Object> benchmarks = new LinkedHashMap<>();

        try {
            // Platform averages
            long totalOrganisers = eventRepository.count() > 0 ?
                    eventRepository.findAll(PageRequest.of(0, 1)).getTotalElements() : 1;

            // Average events per organiser
            // Average registrations per event
            // These would need custom queries - simplified here

            benchmarks.put("platformAvgEventsPerOrganiser", 5); // Placeholder
            benchmarks.put("platformAvgRegistrationsPerEvent", 25); // Placeholder
            benchmarks.put("platformAvgApprovalRate", 85.0); // Placeholder

        } catch (Exception e) {
            log.warn("Could not gather benchmarks: {}", e.getMessage());
        }

        return benchmarks;
    }

    private String buildOrganiserInsightsSystemPrompt() {
        return """
            You are an AI business analyst for an event management platform.
            Your task is to analyze organiser performance data and provide actionable insights.

            Guidelines:
            1. Provide 4-6 specific, actionable insights
            2. Compare performance against benchmarks when available
            3. Identify strengths and areas for improvement
            4. Be encouraging but realistic
            5. Use Vietnamese if organiser data suggests Vietnamese context, otherwise English
            6. Return ONLY valid JSON

            Response format:
            {
              "summary": "Brief overview of performance",
              "performanceScore": 75,
              "insights": [
                {
                  "type": "success|warning|info|tip",
                  "title": "Short title",
                  "description": "Detailed description with specific numbers",
                  "actionText": "Optional button text",
                  "priority": "high|medium|low"
                }
              ],
              "recommendations": [
                "Specific recommendation 1",
                "Specific recommendation 2"
              ]
            }
            """;
    }

    private String buildOrganiserInsightsUserPrompt(Map<String, Object> stats, Map<String, Object> benchmarks) {
        StringBuilder sb = new StringBuilder();
        sb.append("Analyze this organiser's performance:\n\n");

        sb.append("=== ORGANISER STATISTICS ===\n");
        sb.append("Events: ").append(stats.get("totalEvents")).append(" total\n");
        sb.append("  - Published: ").append(stats.get("publishedEvents")).append("\n");
        sb.append("  - Completed: ").append(stats.get("completedEvents")).append("\n");
        sb.append("  - Drafts: ").append(stats.get("draftEvents")).append("\n\n");

        sb.append("Registrations: ").append(stats.get("totalRegistrations")).append(" total\n");
        sb.append("  - Approved: ").append(stats.get("approvedRegistrations")).append("\n");
        sb.append("  - Pending: ").append(stats.get("pendingRegistrations")).append("\n");
        sb.append("  - Approval Rate: ").append(stats.get("approvalRate")).append("%\n\n");

        sb.append("Engagement:\n");
        sb.append("  - Followers: ").append(stats.get("followers")).append("\n");
        sb.append("  - Total Revenue: ").append(stats.get("totalRevenue")).append(" VND\n");
        sb.append("  - Questions: ").append(stats.get("totalQuestions")).append("\n");
        sb.append("  - Unanswered: ").append(stats.get("unansweredQuestions")).append("\n");
        sb.append("  - Response Rate: ").append(stats.get("questionResponseRate")).append("%\n\n");

        if (stats.containsKey("recentEvents")) {
            sb.append("=== RECENT EVENTS PERFORMANCE ===\n");
            List<Map<String, Object>> recentEvents = (List<Map<String, Object>>) stats.get("recentEvents");
            for (Map<String, Object> event : recentEvents) {
                sb.append("- ").append(event.get("title"));
                sb.append(" [").append(event.get("status")).append("]");
                sb.append(": ").append(event.get("registrations"));
                if (event.containsKey("capacity") && event.get("capacity") != null) {
                    sb.append("/").append(event.get("capacity"));
                }
                if (event.containsKey("fillRate")) {
                    sb.append(" (").append(event.get("fillRate")).append("% filled)");
                }
                sb.append("\n");
            }
        }

        sb.append("\n=== PLATFORM BENCHMARKS ===\n");
        sb.append("Average events per organiser: ").append(benchmarks.get("platformAvgEventsPerOrganiser")).append("\n");
        sb.append("Average registrations per event: ").append(benchmarks.get("platformAvgRegistrationsPerEvent")).append("\n");
        sb.append("Average approval rate: ").append(benchmarks.get("platformAvgApprovalRate")).append("%\n");

        sb.append("\nProvide actionable insights. Return ONLY valid JSON.");

        return sb.toString();
    }

    private Map<String, Object> createFallbackInsights(Map<String, Object> stats) {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("summary", "Phân tích dữ liệu của bạn.");
        result.put("performanceScore", 70);

        List<Map<String, Object>> insights = new ArrayList<>();

        // Basic insights from stats
        Map<String, Object> insight1 = new LinkedHashMap<>();
        insight1.put("type", "info");
        insight1.put("title", "Tổng quan sự kiện");
        insight1.put("description", "Bạn có " + stats.get("totalEvents") + " sự kiện với " +
                stats.get("totalRegistrations") + " đăng ký.");
        insight1.put("priority", "medium");
        insights.add(insight1);

        long pending = (long) stats.getOrDefault("pendingRegistrations", 0L);
        if (pending > 0) {
            Map<String, Object> insight2 = new LinkedHashMap<>();
            insight2.put("type", "warning");
            insight2.put("title", "Đăng ký chờ xử lý");
            insight2.put("description", "Bạn có " + pending + " đăng ký đang chờ duyệt.");
            insight2.put("actionText", "Xem ngay");
            insight2.put("priority", "high");
            insights.add(insight2);
        }

        long unanswered = (long) stats.getOrDefault("unansweredQuestions", 0L);
        if (unanswered > 0) {
            Map<String, Object> insight3 = new LinkedHashMap<>();
            insight3.put("type", "warning");
            insight3.put("title", "Câu hỏi chưa trả lời");
            insight3.put("description", "Bạn có " + unanswered + " câu hỏi chưa được trả lời.");
            insight3.put("actionText", "Trả lời ngay");
            insight3.put("priority", "high");
            insights.add(insight3);
        }

        result.put("insights", insights);
        result.put("rawStats", stats);

        return result;
    }

    // ==================== Common Utilities ====================

    private String callGroqApi(String systemPrompt, String userPrompt, int maxTokens) {
        try {
            Map<String, Object> requestBody = new LinkedHashMap<>();
            requestBody.put("model", model);
            requestBody.put("max_tokens", maxTokens);
            requestBody.put("temperature", 0.7);

            List<Map<String, String>> messages = new ArrayList<>();
            messages.add(Map.of("role", "system", "content", systemPrompt));
            messages.add(Map.of("role", "user", "content", userPrompt));
            requestBody.put("messages", messages);

            String requestJson = objectMapper.writeValueAsString(requestBody);

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);

            HttpEntity<String> entity = new HttpEntity<>(requestJson, headers);

            String responseStr = groqRestTemplate.postForObject(GROQ_API_URL, entity, String.class);

            JsonNode responseJson = objectMapper.readTree(responseStr);
            JsonNode choices = responseJson.get("choices");

            if (choices != null && choices.isArray() && !choices.isEmpty()) {
                return choices.get(0).get("message").get("content").asText().trim();
            }

            return "Unable to generate content.";
        } catch (Exception e) {
            log.error("Error calling Groq API: ", e);
            throw new RuntimeException("Failed to generate AI content: " + e.getMessage());
        }
    }

    private String cleanJsonResponse(String response) {
        String cleanJson = response.trim();
        if (cleanJson.startsWith("```json")) {
            cleanJson = cleanJson.substring(7);
        }
        if (cleanJson.startsWith("```")) {
            cleanJson = cleanJson.substring(3);
        }
        if (cleanJson.endsWith("```")) {
            cleanJson = cleanJson.substring(0, cleanJson.length() - 3);
        }
        return cleanJson.trim();
    }

    private String truncate(String text, int maxLength) {
        if (text == null) return "";
        return text.length() > maxLength ? text.substring(0, maxLength) + "..." : text;
    }
}
