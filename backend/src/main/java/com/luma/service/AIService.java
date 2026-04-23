package com.luma.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.luma.entity.Event;
import com.luma.entity.Question;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
@Slf4j
public class AIService {

    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;
    private final String model;

    private static final String OPENAI_API_URL = "https://api.openai.com/v1/chat/completions";

    public AIService(
            RestTemplate openaiRestTemplate,
            @Value("${openai.model:gpt-4o-mini}") String model) {
        this.restTemplate = openaiRestTemplate;
        this.model = model;
        this.objectMapper = new ObjectMapper();
        log.info("AIService initialized with OpenAI model: {}", model);
    }

    public String suggestAnswer(Question question) {
        Event event = question.getEvent();

        String systemPrompt = buildSystemPrompt(event);
        String userPrompt = buildUserPrompt(question);

        try {
            log.info("Calling OpenAI API with model: {}", model);

            Map<String, Object> requestBody = new LinkedHashMap<>();
            requestBody.put("model", model);
            requestBody.put("max_tokens", 500);
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
            log.debug("OpenAI Request JSON: {}", requestJson);

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);

            HttpEntity<String> entity = new HttpEntity<>(requestJson, headers);

            String responseStr = restTemplate.postForObject(OPENAI_API_URL, entity, String.class);

            JsonNode responseJson = objectMapper.readTree(responseStr);
            JsonNode choices = responseJson.get("choices");

            if (choices != null && choices.isArray() && choices.size() > 0) {
                return choices.get(0).get("message").get("content").asText().trim();
            }

            return "Unable to generate suggestion. Please try again.";
        } catch (Exception e) {
            log.error("Error calling OpenAI API: ", e);
            throw new RuntimeException("Failed to generate AI suggestion: " + e.getMessage());
        }
    }

    private String buildSystemPrompt(Event event) {
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");

        StringBuilder sb = new StringBuilder();
        sb.append("You are an AI assistant for event organizers. ");
        sb.append("Your task is to suggest answers for questions from attendees.\n\n");
        sb.append("CRITICAL LANGUAGE RULE - YOU MUST FOLLOW THIS:\n");
        sb.append("- Detect the language of the QUESTION text\n");
        sb.append("- If the question contains Vietnamese characters (ă, â, đ, ê, ô, ơ, ư, etc.) or Vietnamese words → respond in Vietnamese\n");
        sb.append("- If the question is in English → respond in English\n");
        sb.append("- NEVER respond in a different language than the question\n\n");
        sb.append("Event Information:\n");
        sb.append("- Event name: ").append(event.getTitle()).append("\n");

        if (event.getDescription() != null) {
            sb.append("- Description: ").append(event.getDescription()).append("\n");
        }

        if (event.getStartTime() != null) {
            sb.append("- Start time: ").append(event.getStartTime().format(formatter)).append("\n");
        }

        if (event.getEndTime() != null) {
            sb.append("- End time: ").append(event.getEndTime().format(formatter)).append("\n");
        }

        if (event.getVenue() != null) {
            sb.append("- Venue: ").append(event.getVenue()).append("\n");
        }

        if (event.getAddress() != null) {
            sb.append("- Address: ").append(event.getAddress()).append("\n");
        }

        if (event.getTicketPrice() != null && event.getTicketPrice().doubleValue() > 0) {
            sb.append("- Ticket price: ").append(event.getTicketPrice()).append(" USD\n");
        } else {
            sb.append("- Ticket price: Free\n");
        }

        if (event.getCapacity() != null) {
            sb.append("- Maximum capacity: ").append(event.getCapacity()).append("\n");
        }

        sb.append("\nGuidelines:\n");
        sb.append("1. Keep the answer concise, professional, and friendly\n");
        sb.append("2. Use the event information to answer accurately\n");
        sb.append("3. If there is not enough information, suggest a reasonable answer\n");
        sb.append("4. CRITICAL: Match the language of your response to the language of the question exactly\n");

        return sb.toString();
    }

    private String buildUserPrompt(Question question) {
        String questionText = question.getQuestion();
        boolean isEnglish = !questionText.matches(".*[àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđĐ].*");
        String langHint = isEnglish ? "The question is in ENGLISH. You MUST respond in ENGLISH only."
                                    : "Câu hỏi bằng tiếng Việt. Bạn PHẢI trả lời bằng TIẾNG VIỆT.";

        return "Question from attendee \"" + question.getUser().getFullName() + "\":\n" +
               questionText + "\n\n" +
               langHint;
    }

    public String generateEventDescription(String title, String category, String venue,
                                           String address, String startTime, String endTime) {
        String systemPrompt = """
            You are an expert event marketing copywriter. Your task is to write compelling event descriptions.

            Guidelines:
            1. Write in Markdown format
            2. Make it engaging and professional
            3. Include sections: Overview, What to Expect, Who Should Attend
            4. Keep it concise (150-250 words)
            5. Use bullet points where appropriate
            6. Detect language from the title - if Vietnamese title, write in Vietnamese; if English, write in English
            7. Do NOT include the event title in the description (it will be shown separately)
            """;

        StringBuilder userPrompt = new StringBuilder();
        userPrompt.append("Generate an event description for:\n\n");
        userPrompt.append("Title: ").append(title).append("\n");
        if (category != null && !category.isEmpty()) {
            userPrompt.append("Category: ").append(category).append("\n");
        }
        if (venue != null && !venue.isEmpty()) {
            userPrompt.append("Venue: ").append(venue).append("\n");
        }
        if (address != null && !address.isEmpty()) {
            userPrompt.append("Address: ").append(address).append("\n");
        }
        if (startTime != null && !startTime.isEmpty()) {
            userPrompt.append("Start Time: ").append(startTime).append("\n");
        }
        if (endTime != null && !endTime.isEmpty()) {
            userPrompt.append("End Time: ").append(endTime).append("\n");
        }

        return callOpenAiApi(systemPrompt, userPrompt.toString(), 800);
    }

    public String improveEventDescription(String title, String currentDescription) {
        String systemPrompt = """
            You are an expert editor and event marketing specialist. Your task is to improve event descriptions.

            Guidelines:
            1. Fix any grammar and spelling errors
            2. Make the text more engaging and professional
            3. Improve structure and readability
            4. Keep the same language as the original
            5. Output in Markdown format
            6. Keep similar length to original (don't make it much longer)
            7. Preserve the key information and meaning
            8. Do NOT include the event title in the description
            """;

        String userPrompt = "Improve this event description:\n\n" +
                "Event Title: " + title + "\n\n" +
                "Current Description:\n" + currentDescription;

        return callOpenAiApi(systemPrompt, userPrompt, 800);
    }

    public String generateSpeakerBio(String name, String title, String eventTitle) {
        String systemPrompt = """
            You are a professional bio writer. Your task is to write a brief, professional speaker bio.

            Guidelines:
            1. Write 2-3 sentences only
            2. Make it sound professional and credible
            3. Detect language from the name/title - if Vietnamese, write in Vietnamese; if English, write in English
            4. Focus on expertise implied by the title
            5. Do NOT make up specific achievements or numbers
            6. Keep it general but professional
            """;

        StringBuilder userPrompt = new StringBuilder();
        userPrompt.append("Generate a speaker bio for:\n\n");
        userPrompt.append("Name: ").append(name).append("\n");
        userPrompt.append("Title/Position: ").append(title).append("\n");
        if (eventTitle != null && !eventTitle.isEmpty()) {
            userPrompt.append("Speaking at event: ").append(eventTitle).append("\n");
        }

        return callOpenAiApi(systemPrompt, userPrompt.toString(), 200);
    }

    public String generateNotificationMessage(String eventTitle, String notificationType, String additionalContext) {
        String systemPrompt = """
            You are an event communication specialist. Your task is to write notification messages for event attendees.

            Guidelines:
            1. Keep it concise (2-4 sentences)
            2. Be friendly and professional
            3. Include a clear call-to-action if appropriate
            4. Detect language from the event title - if Vietnamese, write in Vietnamese; if English, write in English
            5. Match the tone to the notification type (urgent, informational, reminder, etc.)
            """;

        StringBuilder userPrompt = new StringBuilder();
        userPrompt.append("Generate a notification message for:\n\n");
        userPrompt.append("Event: ").append(eventTitle).append("\n");
        userPrompt.append("Notification Type: ").append(notificationType).append("\n");
        if (additionalContext != null && !additionalContext.isEmpty()) {
            userPrompt.append("Additional Context: ").append(additionalContext).append("\n");
        }

        return callOpenAiApi(systemPrompt, userPrompt.toString(), 300);
    }

    public String suggestRegistrationQuestions(String eventTitle, String eventCategory, String eventDescription, int numberOfQuestions) {
        String systemPrompt = """
            You are an event registration specialist. Your task is to suggest registration questions for event organizers.

            Guidelines:
            1. Suggest practical questions that help organizers understand their attendees
            2. Include a mix of question types: TEXT (short answer), TEXTAREA (long answer), SINGLE_CHOICE, MULTIPLE_CHOICE
            3. For choice questions, provide 3-5 relevant options
            4. Questions should be relevant to the event type/category
            5. Detect language from event title - if Vietnamese, write questions in Vietnamese; if English, write in English
            6. Return ONLY a valid JSON array with no extra text
            7. Each question object should have: questionText, questionType, options (array, null for TEXT/TEXTAREA), required (boolean)

            Example format:
            [
              {"questionText": "What is your job title?", "questionType": "TEXT", "options": null, "required": true},
              {"questionText": "How did you hear about this event?", "questionType": "SINGLE_CHOICE", "options": ["Social Media", "Friend", "Email", "Website", "Other"], "required": false},
              {"questionText": "What topics interest you most?", "questionType": "MULTIPLE_CHOICE", "options": ["Topic A", "Topic B", "Topic C", "Topic D"], "required": true}
            ]
            """;

        StringBuilder userPrompt = new StringBuilder();
        userPrompt.append("Suggest ").append(numberOfQuestions).append(" registration questions for this event:\n\n");
        userPrompt.append("Event Title: ").append(eventTitle).append("\n");
        if (eventCategory != null && !eventCategory.isEmpty()) {
            userPrompt.append("Category: ").append(eventCategory).append("\n");
        }
        if (eventDescription != null && !eventDescription.isEmpty()) {
            String shortDesc = eventDescription.length() > 500
                ? eventDescription.substring(0, 500) + "..."
                : eventDescription;
            userPrompt.append("Description: ").append(shortDesc).append("\n");
        }
        userPrompt.append("\nReturn ONLY a JSON array with the questions.");

        return callOpenAiApi(systemPrompt, userPrompt.toString(), 1000);
    }

    public String generateDashboardInsights(
            long totalEvents, long publishedEvents, long draftEvents,
            long totalRegistrations, long approvedRegistrations, long pendingRegistrations,
            long totalFollowers, double totalRevenue,
            String recentEventsInfo, String registrationTrend) {

        String systemPrompt = """
            You are an expert event management consultant. Your task is to analyze organiser's dashboard data and provide actionable insights.

            Guidelines:
            1. Provide 3-5 specific, actionable recommendations
            2. Be encouraging but realistic
            3. Focus on growth opportunities and improvements
            4. Use data to support your suggestions
            5. Detect language from recentEventsInfo - if Vietnamese event names, respond in Vietnamese; if English, respond in English
            6. Return ONLY a valid JSON object with no extra text
            7. Each insight should have: type (success/warning/info/tip), title, description, actionText (optional button text)

            Example format:
            {
              "summary": "Your events are performing well with steady growth.",
              "insights": [
                {"type": "success", "title": "Strong Registration Rate", "description": "Your approval rate is 85%, above industry average.", "actionText": null},
                {"type": "tip", "title": "Optimal Timing", "description": "Based on your data, weekends show 30% higher registrations.", "actionText": "Schedule Event"},
                {"type": "warning", "title": "Pending Reviews", "description": "You have 5 pending registrations. Quick responses improve attendee satisfaction.", "actionText": "Review Now"},
                {"type": "info", "title": "Price Optimization", "description": "Similar events in your category average 50,000đ. Consider adjusting.", "actionText": null}
              ]
            }
            """;

        StringBuilder userPrompt = new StringBuilder();
        userPrompt.append("Analyze this organiser's dashboard data and provide insights:\n\n");
        userPrompt.append("=== EVENT STATISTICS ===\n");
        userPrompt.append("Total Events: ").append(totalEvents).append("\n");
        userPrompt.append("Published Events: ").append(publishedEvents).append("\n");
        userPrompt.append("Draft Events: ").append(draftEvents).append("\n");
        userPrompt.append("\n=== REGISTRATION STATISTICS ===\n");
        userPrompt.append("Total Registrations: ").append(totalRegistrations).append("\n");
        userPrompt.append("Approved: ").append(approvedRegistrations).append("\n");
        userPrompt.append("Pending: ").append(pendingRegistrations).append("\n");
        userPrompt.append("\n=== OTHER METRICS ===\n");
        userPrompt.append("Total Followers: ").append(totalFollowers).append("\n");
        userPrompt.append("Total Revenue: ").append(String.format("%.0f", totalRevenue)).append(" VND\n");

        if (recentEventsInfo != null && !recentEventsInfo.isEmpty()) {
            userPrompt.append("\n=== RECENT EVENTS ===\n");
            userPrompt.append(recentEventsInfo).append("\n");
        }

        if (registrationTrend != null && !registrationTrend.isEmpty()) {
            userPrompt.append("\n=== REGISTRATION TREND (Last 30 days) ===\n");
            userPrompt.append(registrationTrend).append("\n");
        }

        userPrompt.append("\nProvide actionable insights based on this data. Return ONLY valid JSON.");

        return callOpenAiApi(systemPrompt, userPrompt.toString(), 1000);
    }

    public String analyzeEventForModeration(String title, String description, String organiserName,
                                             String category, String venue, String startTime,
                                             Integer capacity, Double ticketPrice) {
        String systemPrompt = """
            You are an expert event moderator for an event management platform. Your task is to analyze submitted events and provide moderation recommendations.

            Guidelines:
            1. Check for content quality, completeness, and appropriateness
            2. Flag any potential issues: spam, inappropriate content, missing information, unrealistic claims
            3. Provide a quality score from 0-100
            4. Recommend APPROVE, REJECT, or NEEDS_REVIEW
            5. If recommending reject, provide specific reasons
            6. Detect language from event title/description - respond in the same language
            7. Return ONLY a valid JSON object

            Example format:
            {
              "recommendation": "APPROVE",
              "qualityScore": 85,
              "summary": "Well-structured event with complete information.",
              "strengths": ["Clear description", "Professional organiser", "Reasonable pricing"],
              "concerns": [],
              "suggestedAction": "This event meets all quality standards and can be approved.",
              "rejectionReason": null
            }

            For rejection:
            {
              "recommendation": "REJECT",
              "qualityScore": 25,
              "summary": "Event has significant quality issues.",
              "strengths": [],
              "concerns": ["Vague description", "Missing venue details", "Suspicious pricing"],
              "suggestedAction": "Request organiser to provide more details.",
              "rejectionReason": "Sự kiện thiếu thông tin chi tiết về địa điểm và nội dung chương trình. Vui lòng cập nhật mô tả đầy đủ hơn."
            }
            """;

        StringBuilder userPrompt = new StringBuilder();
        userPrompt.append("Analyze this event submission for moderation:\n\n");
        userPrompt.append("=== EVENT DETAILS ===\n");
        userPrompt.append("Title: ").append(title).append("\n");
        userPrompt.append("Organiser: ").append(organiserName).append("\n");
        userPrompt.append("Category: ").append(category != null ? category : "Not specified").append("\n");
        userPrompt.append("Venue: ").append(venue != null ? venue : "Not specified").append("\n");
        userPrompt.append("Start Time: ").append(startTime != null ? startTime : "Not specified").append("\n");
        userPrompt.append("Capacity: ").append(capacity != null ? capacity : "Not specified").append("\n");
        userPrompt.append("Ticket Price: ").append(ticketPrice != null && ticketPrice > 0 ? ticketPrice + " VND" : "Free").append("\n");
        userPrompt.append("\n=== DESCRIPTION ===\n");
        userPrompt.append(description != null && !description.isEmpty() ? description : "No description provided");
        userPrompt.append("\n\nProvide moderation analysis. Return ONLY valid JSON.");

        return callOpenAiApi(systemPrompt, userPrompt.toString(), 800);
    }

    public String generateRejectionReason(String title, String description, String concerns) {
        String systemPrompt = """
            You are a professional event platform moderator. Your task is to write a polite, helpful rejection message for an event submission.

            Guidelines:
            1. Be professional and respectful
            2. Clearly explain what needs to be improved
            3. Provide specific, actionable feedback
            4. Encourage the organiser to resubmit after making improvements
            5. Detect language from event title - if Vietnamese, write in Vietnamese; if English, write in English
            6. Keep it concise (2-4 sentences)
            7. Do NOT be harsh or discouraging
            """;

        StringBuilder userPrompt = new StringBuilder();
        userPrompt.append("Generate a rejection message for this event:\n\n");
        userPrompt.append("Event Title: ").append(title).append("\n");
        if (description != null && !description.isEmpty()) {
            String shortDesc = description.length() > 300 ? description.substring(0, 300) + "..." : description;
            userPrompt.append("Description preview: ").append(shortDesc).append("\n");
        }
        if (concerns != null && !concerns.isEmpty()) {
            userPrompt.append("Concerns to address: ").append(concerns).append("\n");
        }
        userPrompt.append("\nWrite a polite rejection message explaining the issues and encouraging improvement.");

        return callOpenAiApi(systemPrompt, userPrompt.toString(), 300);
    }

    public String generateBroadcastMessage(String purpose, String targetAudience, String additionalContext) {
        String systemPrompt = """
            You are a platform communication specialist. Your task is to write broadcast notification messages for platform administrators.

            Guidelines:
            1. Be clear, professional, and engaging
            2. Match the tone to the purpose (announcement, update, warning, celebration)
            3. Keep it concise but informative (2-4 sentences)
            4. Include a call-to-action if appropriate
            5. Detect language from context - default to Vietnamese if unclear
            6. Make the message feel personal, not robotic
            """;

        StringBuilder userPrompt = new StringBuilder();
        userPrompt.append("Generate a broadcast notification message:\n\n");
        userPrompt.append("Purpose: ").append(purpose).append("\n");
        userPrompt.append("Target Audience: ").append(targetAudience).append("\n");
        if (additionalContext != null && !additionalContext.isEmpty()) {
            userPrompt.append("Additional Context: ").append(additionalContext).append("\n");
        }
        userPrompt.append("\nWrite an engaging broadcast message.");

        return callOpenAiApi(systemPrompt, userPrompt.toString(), 300);
    }

    public String generateAdminInsights(long totalUsers, long totalOrganisers, long totalEvents,
                                         long totalRegistrations, long newUsersThisMonth,
                                         long newEventsThisMonth, long pendingEvents,
                                         long verifiedOrganisers, long unverifiedOrganisers,
                                         long lowRegistrationEvents, String topCategories, String topCities) {
        String systemPrompt = """
            You are a platform administrator analyst for an event management platform (like Eventbrite/Luma).
            Your task is to analyze platform data and provide ACTIONABLE insights for the ADMIN team.

            IMPORTANT: You are advising the PLATFORM ADMINISTRATOR, not event organisers.
            Focus on:
            - Platform health and growth
            - Organiser management (who to verify, who needs attention)
            - Event quality control (pending approvals, low quality events)
            - System alerts and concerns

            Guidelines:
            1. Provide 4-6 specific insights based on the data
            2. Focus on platform management tasks, NOT marketing advice
            3. Highlight urgent items that need admin attention
            4. ALWAYS use English language
            5. Return ONLY a valid JSON object

            Insight types to use:
            - "success": Good metrics, achievements
            - "warning": Issues needing attention (pending events, inactive organisers)
            - "info": Neutral observations, statistics
            - "tip": Suggestions for platform improvement

            Example format:
            {
              "summary": "Platform is growing steadily. 3 items need your attention.",
              "insights": [
                {"type": "warning", "title": "Pending Event Approvals", "description": "5 events waiting for review for over 24 hours. Quick approval improves organiser satisfaction.", "actionText": "Review Events"},
                {"type": "success", "title": "User Growth", "description": "23 new users this month, 15% increase from last month.", "actionText": null},
                {"type": "tip", "title": "Organiser Verification", "description": "3 organisers have hosted 5+ successful events but are not verified. Consider verifying them.", "actionText": "View Organisers"},
                {"type": "warning", "title": "Low Registration Events", "description": "4 published events have less than 10% capacity filled. May need quality review.", "actionText": "Check Events"},
                {"type": "info", "title": "Category Distribution", "description": "Technology events dominate at 45%. Consider promoting other categories.", "actionText": null}
              ]
            }
            """;

        StringBuilder userPrompt = new StringBuilder();
        userPrompt.append("Analyze this platform data for ADMIN dashboard:\n\n");
        userPrompt.append("=== PLATFORM OVERVIEW ===\n");
        userPrompt.append("Total Users: ").append(totalUsers).append("\n");
        userPrompt.append("Total Organisers: ").append(totalOrganisers).append("\n");
        userPrompt.append("  - Verified: ").append(verifiedOrganisers).append("\n");
        userPrompt.append("  - Unverified: ").append(unverifiedOrganisers).append("\n");
        userPrompt.append("Total Events: ").append(totalEvents).append("\n");
        userPrompt.append("Total Registrations: ").append(totalRegistrations).append("\n");
        userPrompt.append("\n=== ITEMS NEEDING ATTENTION ===\n");
        userPrompt.append("Events Pending Approval: ").append(pendingEvents).append("\n");
        userPrompt.append("Events with Low Registration (<20%): ").append(lowRegistrationEvents).append("\n");
        userPrompt.append("\n=== RECENT ACTIVITY (This Month) ===\n");
        userPrompt.append("New Users: ").append(newUsersThisMonth).append("\n");
        userPrompt.append("New Events: ").append(newEventsThisMonth).append("\n");
        if (topCategories != null && !topCategories.isEmpty()) {
            userPrompt.append("\n=== TOP CATEGORIES ===\n").append(topCategories);
        }
        if (topCities != null && !topCities.isEmpty()) {
            userPrompt.append("\n=== TOP CITIES ===\n").append(topCities);
        }
        userPrompt.append("\n\nProvide actionable insights for the ADMIN team. Focus on platform management, not marketing. Return ONLY valid JSON.");

        return callOpenAiApi(systemPrompt, userPrompt.toString(), 1200);
    }

    public String generateCoupon(String description, String discountType, BigDecimal discountValue,
                                  BigDecimal maxDiscountAmount, BigDecimal minOrderAmount,
                                  Integer maxUsageCount, Integer maxUsagePerUser,
                                  LocalDateTime validFrom, LocalDateTime validUntil,
                                  String eventName, String language) {
        String systemPrompt = """
            You are a coupon marketing specialist. Your task is to generate creative coupon codes and descriptions.

            CRITICAL RULES:
            1. Generate a unique, creative coupon CODE (8-12 characters, alphanumeric, uppercase)
            2. Write an engaging DESCRIPTION (50-100 words) explaining the offer
            3. Suggest improvements to the discount parameters if needed
            4. Return ONLY valid JSON with no extra text

            JSON format:
            {
              "code": "CREATIVECODE",
              "description": "Compelling description here...",
              "suggestedDiscountType": "PERCENTAGE or FIXED_AMOUNT",
              "suggestedDiscountValue": 20,
              "suggestedMaxDiscountAmount": 50,
              "suggestedMinOrderAmount": 100,
              "suggestedMaxUsageCount": 100,
              "suggestedMaxUsagePerUser": 1,
              "suggestedValidFrom": "2026-05-01T00:00:00",
              "suggestedValidUntil": "2026-05-31T23:59:59",
              "suggestedValidDays": 30,
              "reasoning": "Brief explanation of why these settings work well"
            }

            Guidelines:
            - Code should be memorable and relevant to the event/promotion
            - Description should create urgency and excitement
            - If PERCENTAGE: suggest 10-50% with max cap if needed
            - If FIXED_AMOUNT: suggest $5-$100 depending on context
            - Consider the event type and target audience
            """;

        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");

        StringBuilder userPrompt = new StringBuilder();
        userPrompt.append("Generate a coupon for:\n\n");
        if (eventName != null && !eventName.isEmpty()) {
            userPrompt.append("Event: ").append(eventName).append("\n");
        }
        if (description != null && !description.isEmpty()) {
            userPrompt.append("User's description: ").append(description).append("\n");
        }
        userPrompt.append("\nCurrent Settings:\n");
        userPrompt.append("Discount Type: ").append(discountType != null ? discountType : "Not specified").append("\n");
        userPrompt.append("Discount Value: ").append(discountValue != null ? discountValue : "Not specified").append("\n");
        if (maxDiscountAmount != null) {
            userPrompt.append("Max Discount: ").append(maxDiscountAmount).append("\n");
        }
        if (minOrderAmount != null) {
            userPrompt.append("Min Order: ").append(minOrderAmount).append("\n");
        }
        if (maxUsageCount != null) {
            userPrompt.append("Max Usage: ").append(maxUsageCount).append("\n");
        }
        if (maxUsagePerUser != null) {
            userPrompt.append("Max Per User: ").append(maxUsagePerUser).append("\n");
        }
        if (validFrom != null) {
            userPrompt.append("Valid From: ").append(validFrom.format(formatter)).append("\n");
        }
        if (validUntil != null) {
            userPrompt.append("Valid Until: ").append(validUntil.format(formatter)).append("\n");
        }
        userPrompt.append("\nLanguage: ").append("vi".equals(language) ? "Vietnamese" : "English").append("\n");
        userPrompt.append("\nGenerate creative coupon code and description. Return ONLY valid JSON.");

        return callOpenAiApi(systemPrompt, userPrompt.toString(), 800);
    }

    public String generateOrganiserBio(String organizationName, String eventTypes, String targetAudience, String additionalInfo) {
        String systemPrompt = """
            You are an expert copywriter specializing in professional bios for event organizers.

            IMPORTANT RULES:
            1. Write in Markdown format for rich text display
            2. Use formatting: **bold** for emphasis, *italic* for highlights
            3. Write 3-4 paragraphs, separated by empty lines
            4. Total length: 150-200 words
            5. Structure:
               - Paragraph 1: Introduction - who they are (use **bold** for organization name)
               - Paragraph 2: What they do - types of events, services
               - Paragraph 3: Their mission, values, or approach
               - Paragraph 4 (optional): Call to action or invitation
            6. Detect language from organization name:
               - Vietnamese name → write in Vietnamese
               - English name → write in English
            7. Be specific and meaningful - avoid generic phrases
            8. Do NOT make up numbers, awards, or achievements
            9. Sound professional but warm and approachable
            """;

        StringBuilder userPrompt = new StringBuilder();
        userPrompt.append("Write a bio for: ").append(organizationName).append("\n");
        if (eventTypes != null && !eventTypes.isEmpty()) {
            userPrompt.append("Event types: ").append(eventTypes).append("\n");
        }
        if (targetAudience != null && !targetAudience.isEmpty()) {
            userPrompt.append("Target audience: ").append(targetAudience).append("\n");
        }
        if (additionalInfo != null && !additionalInfo.isEmpty()) {
            userPrompt.append("Website/Info: ").append(additionalInfo).append("\n");
        }
        userPrompt.append("\nWrite a detailed bio in Markdown format with proper formatting. 150-200 words, 3-4 paragraphs.");

        return callOpenAiApi(systemPrompt, userPrompt.toString(), 400);
    }

    public String moderateReviewContent(String reviewText, int rating, String eventTitle) {
        String systemPrompt = """
            You are a content moderation AI for an event management platform. Your task is to analyze user reviews and detect inappropriate content.

            Check for these categories:
            1. SPAM: Promotional content, advertisements, unrelated links, repetitive text
            2. TOXIC: Hate speech, discrimination, severe insults, threats
            3. PROFANITY: Strong swear words, vulgar language
            4. HARASSMENT: Personal attacks on organizers/attendees, bullying
            5. FAKE: Obviously fake reviews, irrelevant to event (e.g., 1 star with "great event!" comment)
            6. OFF_TOPIC: Content completely unrelated to the event - random questions, gibberish, or text that has nothing to do with reviewing the event experience

            Guidelines:
            1. Be lenient with mild criticism - negative but constructive reviews are OK
            2. Consider rating-comment consistency (low rating with positive comment = suspicious)
            3. Check both English and Vietnamese content
            4. Return toxicityScore 0-100 (0=safe, 100=highly toxic)
            5. isAppropriate = true if toxicityScore < 60
            6. OFF_TOPIC reviews should have toxicityScore >= 80 (to be rejected)
            7. Return ONLY valid JSON

            Example responses:

            Safe review:
            {"isAppropriate": true, "toxicityScore": 5, "categories": [], "reason": null, "suggestion": null}

            Mild concern (still appropriate):
            {"isAppropriate": true, "toxicityScore": 35, "categories": ["MILD_NEGATIVITY"], "reason": "Contains strong criticism but within acceptable bounds", "suggestion": null}

            Inappropriate review:
            {"isAppropriate": false, "toxicityScore": 85, "categories": ["TOXIC", "HARASSMENT"], "reason": "Contains personal attacks on the organizer", "suggestion": "Remove personal attacks and focus on event feedback"}

            Spam review:
            {"isAppropriate": false, "toxicityScore": 80, "categories": ["SPAM"], "reason": "Contains promotional links unrelated to event", "suggestion": "Remove promotional content"}

            Fake review:
            {"isAppropriate": false, "toxicityScore": 80, "categories": ["FAKE"], "reason": "Rating-comment mismatch: 1 star rating with positive comment", "suggestion": "Ensure rating matches your actual experience"}

            Off-topic review:
            {"isAppropriate": false, "toxicityScore": 85, "categories": ["OFF_TOPIC"], "reason": "Review content is not related to the event experience", "suggestion": "Please write about your actual experience at this event"}
            """;

        StringBuilder userPrompt = new StringBuilder();
        userPrompt.append("Moderate this review:\n\n");
        userPrompt.append("Event: ").append(eventTitle).append("\n");
        userPrompt.append("Rating: ").append(rating).append("/5 stars\n");
        userPrompt.append("Review text: ").append(reviewText != null ? reviewText : "(no comment)").append("\n");
        userPrompt.append("\nAnalyze and return JSON only.");

        return callOpenAiApi(systemPrompt, userPrompt.toString(), 300);
    }

    public String generateFullEvent(String eventIdea, String eventType, String targetAudience,
                                     String preferredDate, String preferredTime, String cityName, String language,
                                     List<String> existingCategories, List<String> existingCities) {
        String systemPrompt = """
            You are an expert event planner and marketing specialist. Your task is to generate a complete event proposal based on a simple idea.
            You MUST understand user input in both English and Vietnamese (with or without diacritics).

            TODAY'S DATE: %s

            IMPORTANT RULES:
            1. Return ONLY valid JSON - no extra text before or after
            2. Language: Write content in %s (Vietnamese if "vi", English if "en")
            3. Be creative but realistic
            4. Generate 3 different title options
            5. Description should be in Markdown format (150-250 words)
            6. Suggest realistic venue based on event type and city/region
            7. Capacity should match event type (workshop: 20-50, seminar: 50-200, conference: 100-500, meetup: 30-100, party: 50-300)
            8. Price in USD: suggest 0 (FREE) for community/networking events, $10-$200 for professional/premium events
            9. Date/Time: CRITICAL - Parse user's preferred date/time carefully and return ISO format
               - "next X months" or "sau X thang" = add X months from today
               - "next week" = add 7 days from today
               - Vietnamese examples: "15 thang 6" = June 15, "buoi chieu" = 14:00, "buoi toi" = 18:00, "sang" = 09:00
               - "morning to evening" = start at 09:00, end at 18:00
               - If date is in past or not specified, use a date 2-4 weeks from now
               - Duration based on event type: workshop 3h, conference 8h, seminar 2h, meetup 2h, party 4h
            10. City/Region: If user specifies a region (e.g., "Middle East", "Southeast Asia", "Europe"), pick a major city in that region
               - Middle East → Dubai, Abu Dhabi, Riyadh, or Doha
               - Southeast Asia → Singapore, Bangkok, Kuala Lumpur, or Ho Chi Minh City
               - Europe → London, Paris, Berlin, or Amsterdam

            JSON format required:
            {
              "titleSuggestions": ["Title 1", "Title 2", "Title 3"],
              "description": "Markdown description here...",
              "suggestedCategory": "Pick from existing categories if possible: %s. Only create a new category name if none fits.",
              "suggestedVenue": "Venue name suggestion",
              "suggestedAddress": "Full address suggestion with city and country",
              "suggestedCity": "Pick from existing cities if possible: %s. Only suggest a new city name if none fits.",
              "suggestedStartTime": "2024-06-15T14:00:00",
              "suggestedEndTime": "2024-06-15T17:00:00",
              "suggestedCapacity": 100,
              "suggestedPrice": 0,
              "isFree": true,
              "suggestedSpeakers": [
                {"name": "Speaker Name", "title": "Job Title", "bio": "Short bio 1-2 sentences"}
              ]
            }

            For suggestedSpeakers:
            - Workshop/Conference/Seminar: suggest 1-3 speakers with relevant expertise
            - Meetup/Networking/Party: leave empty array []
            """.formatted(
                java.time.LocalDate.now().toString(),
                language.equals("vi") ? "Vietnamese" : "English",
                String.join(", ", existingCategories),
                String.join(", ", existingCities)
            );

        StringBuilder userPrompt = new StringBuilder();
        userPrompt.append("Generate a complete event based on this idea:\n\n");
        userPrompt.append("Event Idea: ").append(eventIdea).append("\n");

        if (eventType != null && !eventType.isEmpty()) {
            userPrompt.append("Event Type: ").append(eventType).append("\n");
        }
        if (targetAudience != null && !targetAudience.isEmpty()) {
            userPrompt.append("Target Audience: ").append(targetAudience).append("\n");
        }
        if (preferredDate != null && !preferredDate.isEmpty()) {
            userPrompt.append("Preferred Date: ").append(preferredDate).append("\n");
        }
        if (preferredTime != null && !preferredTime.isEmpty()) {
            userPrompt.append("Preferred Time: ").append(preferredTime).append("\n");
        }
        if (cityName != null && !cityName.isEmpty()) {
            userPrompt.append("City: ").append(cityName).append("\n");
        }

        userPrompt.append("\nGenerate a complete, professional event proposal. Return ONLY valid JSON.");

        return callOpenAiApi(systemPrompt, userPrompt.toString(), 1500);
    }

    public String generateEventRecommendations(List<Event> userViewedEvents, List<Event> availableEvents, int limit) {
        if (availableEvents.isEmpty()) {
            return "[]";
        }

        StringBuilder systemPrompt = new StringBuilder();
        systemPrompt.append("""
            You are an AI event recommendation engine. Based on the user's viewing history,
            recommend the most relevant events from the available list.

            Consider these factors for recommendations:
            1. Category similarity (same or related categories)
            2. Location proximity (same city or nearby)
            3. Price range similarity
            4. Event type similarity (workshop, conference, meetup, etc.)
            5. Time preferences (similar time slots)

            Return ONLY a JSON array of event IDs in order of relevance, like:
            ["uuid1", "uuid2", "uuid3"]

            Return maximum %d event IDs. Return ONLY the JSON array, no explanation.
            """.formatted(limit));

        StringBuilder userPrompt = new StringBuilder();

        if (userViewedEvents != null && !userViewedEvents.isEmpty()) {
            userPrompt.append("USER'S RECENTLY VIEWED EVENTS:\n");
            for (Event event : userViewedEvents) {
                userPrompt.append(String.format("- %s | Category: %s | City: %s | Price: $%.2f\n",
                        event.getTitle(),
                        event.getCategory() != null ? event.getCategory().getName() : "N/A",
                        event.getCity() != null ? event.getCity().getName() : "N/A",
                        event.getTicketPrice() != null ? event.getTicketPrice().doubleValue() : 0));
            }
            userPrompt.append("\n");
        } else {
            userPrompt.append("USER HAS NO VIEWING HISTORY - Recommend popular/trending events.\n\n");
        }

        userPrompt.append("AVAILABLE EVENTS TO RECOMMEND FROM:\n");
        for (Event event : availableEvents) {
            userPrompt.append(String.format("ID: %s | Title: %s | Category: %s | City: %s | Price: $%.2f | Capacity: %d\n",
                    event.getId().toString(),
                    event.getTitle(),
                    event.getCategory() != null ? event.getCategory().getName() : "N/A",
                    event.getCity() != null ? event.getCity().getName() : "N/A",
                    event.getTicketPrice() != null ? event.getTicketPrice().doubleValue() : 0,
                    event.getCapacity() != null ? event.getCapacity() : 0));
        }

        userPrompt.append("\nReturn the top ").append(limit).append(" most relevant event IDs as JSON array.");

        return callOpenAiApi(systemPrompt.toString(), userPrompt.toString(), 500);
    }

    public String findSimilarEvents(Event sourceEvent, List<Event> candidateEvents, int limit) {
        if (candidateEvents.isEmpty()) {
            return "[]";
        }

        String systemPrompt = """
            You are an AI event similarity engine. Find events most similar to the source event.

            Consider these similarity factors:
            1. Category match (highest priority)
            2. Similar topic/theme in title and description
            3. Same city or region
            4. Similar price range
            5. Similar event type

            Return ONLY a JSON array of event IDs in order of similarity, like:
            ["uuid1", "uuid2", "uuid3"]

            Return maximum %d event IDs. Return ONLY the JSON array, no explanation.
            """.formatted(limit);

        StringBuilder userPrompt = new StringBuilder();
        userPrompt.append("SOURCE EVENT (find similar to this):\n");
        userPrompt.append(String.format("Title: %s\n", sourceEvent.getTitle()));
        userPrompt.append(String.format("Description: %s\n",
                sourceEvent.getDescription() != null ? sourceEvent.getDescription().substring(0, Math.min(200, sourceEvent.getDescription().length())) : "N/A"));
        userPrompt.append(String.format("Category: %s\n", sourceEvent.getCategory() != null ? sourceEvent.getCategory().getName() : "N/A"));
        userPrompt.append(String.format("City: %s\n", sourceEvent.getCity() != null ? sourceEvent.getCity().getName() : "N/A"));
        userPrompt.append(String.format("Price: $%.2f\n\n", sourceEvent.getTicketPrice() != null ? sourceEvent.getTicketPrice().doubleValue() : 0));

        userPrompt.append("CANDIDATE EVENTS:\n");
        for (Event event : candidateEvents) {
            userPrompt.append(String.format("ID: %s | Title: %s | Category: %s | City: %s | Price: $%.2f\n",
                    event.getId().toString(),
                    event.getTitle(),
                    event.getCategory() != null ? event.getCategory().getName() : "N/A",
                    event.getCity() != null ? event.getCity().getName() : "N/A",
                    event.getTicketPrice() != null ? event.getTicketPrice().doubleValue() : 0));
        }

        userPrompt.append("\nReturn the top ").append(limit).append(" most similar event IDs as JSON array.");

        return callOpenAiApi(systemPrompt, userPrompt.toString(), 500);
    }

    public String generatePoll(String topic, Integer numOptions, String pollType, Integer maxRating,
                               Integer numberOfQuestions, String language, String additionalContext) {
        String systemPrompt = """
            You are an expert event engagement specialist. Your task is to generate engaging poll questions and options.

            CRITICAL RULES:
            1. Return ONLY valid JSON, nothing else
            2. Generate poll questions that are clear, engaging, and relevant
            3. For choice options, make them distinct and balanced
            4. Match language to the language preference provided
            5. Create questions that will drive engagement and provide useful data

            JSON format for single question:
            {
              "question": "What is your main interest in attending events?",
              "pollType": "SINGLE_CHOICE",
              "options": ["Networking", "Learning & Skills", "Entertainment", "Career Growth", "Social Experience"]
            }

            For RATING type (ignore options):
            {
              "question": "How likely are you to attend events regularly?",
              "pollType": "RATING",
              "maxRating": 5,
              "options": null
            }

            Guidelines:
            - For SINGLE_CHOICE: Generate 3-5 clear, distinct options
            - For MULTIPLE_CHOICE: Generate 4-6 options covering different aspects
            - For RATING: Create a statement to rate (on a scale)
            - Questions should be concise (5-15 words)
            - Options should be brief (2-4 words each)
            - Ensure relevance to event context
            """;

        StringBuilder userPrompt = new StringBuilder();
        userPrompt.append("Generate poll questions for:\n\n");
        userPrompt.append("Topic: ").append(topic != null && !topic.isEmpty() ? topic : "Event engagement").append("\n");
        userPrompt.append("Poll Type: ").append(pollType != null && !pollType.isEmpty() ? pollType : "SINGLE_CHOICE").append("\n");
        if (numOptions != null && numOptions > 0) {
            userPrompt.append("Number of Options: ").append(numOptions).append("\n");
        }
        if (maxRating != null && maxRating > 0) {
            userPrompt.append("Max Rating: ").append(maxRating).append("\n");
        }
        if (language != null && !language.isEmpty()) {
            userPrompt.append("Language: ").append(language).append("\n");
        } else {
            userPrompt.append("Language: English\n");
        }
        if (additionalContext != null && !additionalContext.isEmpty()) {
            userPrompt.append("Additional Context: ").append(additionalContext).append("\n");
        }

        if (numberOfQuestions != null && numberOfQuestions > 1) {
            userPrompt.append("\nGenerate ").append(numberOfQuestions).append(" different poll questions. Return as a JSON array: [{ question, pollType, options }, ...]");
        } else {
            userPrompt.append("\nGenerate 1 poll question. Return as a JSON object: { question, pollType, options }");
        }
        userPrompt.append("\n\nReturn ONLY valid JSON with no additional text or explanation.");

        return callOpenAiApi(systemPrompt, userPrompt.toString(), 1000);
    }

    public String analyzeVerificationDocument(List<String> imageUrls,
                                               com.luma.entity.enums.VerificationDocumentType documentType) {
        String docLabel = documentType == com.luma.entity.enums.VerificationDocumentType.BUSINESS_LICENSE
                ? "Vietnamese Business Registration Certificate (Giấy chứng nhận đăng ký doanh nghiệp)"
                : "Vietnamese Citizen Identity Card (Căn cước công dân / CCCD)";

        String systemPrompt = """
            You are a document verification assistant for an event platform.
            You will be given one or more images of a document an event organiser uploaded.
            The organiser claims the document is a: %s.

            Your task: decide whether the uploaded images plausibly look like the claimed document.

            Rules:
            1. Do NOT make a final approve/reject decision. A human admin will decide.
            2. Classify into ONE of these statuses:
               - "VALID": Clear image, layout & fields consistent with the claimed document type, no obvious signs of tampering.
               - "SUSPICIOUS": Blurry, partially obscured, low resolution, fields missing, or unusual layout but could still be genuine.
               - "INVALID": Clearly not the claimed document (random photo, screenshot of something else, meme, blank page, test image).
            3. Provide a short reason (1-2 sentences) in Vietnamese explaining what you saw.
            4. Provide a confidence score 0-100 (how confident you are in your classification).
            5. Return ONLY a JSON object, no markdown, no extra text.

            JSON format:
            {
              "status": "VALID" | "SUSPICIOUS" | "INVALID",
              "confidence": 0-100,
              "reason": "Short Vietnamese explanation"
            }
            """.formatted(docLabel);

        try {
            Map<String, Object> requestBody = new LinkedHashMap<>();
            requestBody.put("model", model);
            requestBody.put("max_tokens", 300);
            requestBody.put("temperature", 0.2);

            List<Map<String, Object>> messages = new ArrayList<>();

            Map<String, Object> systemMessage = new LinkedHashMap<>();
            systemMessage.put("role", "system");
            systemMessage.put("content", systemPrompt);
            messages.add(systemMessage);

            List<Map<String, Object>> userContent = new ArrayList<>();
            Map<String, Object> textPart = new LinkedHashMap<>();
            textPart.put("type", "text");
            textPart.put("text", "Claimed document type: " + docLabel
                    + ". Analyze the attached image(s) and return JSON only.");
            userContent.add(textPart);

            for (String url : imageUrls) {
                if (url == null || url.isBlank()) continue;
                Map<String, Object> imagePart = new LinkedHashMap<>();
                imagePart.put("type", "image_url");
                Map<String, Object> imageUrl = new LinkedHashMap<>();
                imageUrl.put("url", url);
                imageUrl.put("detail", "low");
                imagePart.put("image_url", imageUrl);
                userContent.add(imagePart);
            }

            Map<String, Object> userMessage = new LinkedHashMap<>();
            userMessage.put("role", "user");
            userMessage.put("content", userContent);
            messages.add(userMessage);

            requestBody.put("messages", messages);

            String requestJson = objectMapper.writeValueAsString(requestBody);

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);

            HttpEntity<String> entity = new HttpEntity<>(requestJson, headers);

            String responseStr = restTemplate.postForObject(OPENAI_API_URL, entity, String.class);
            JsonNode responseJson = objectMapper.readTree(responseStr);
            JsonNode choices = responseJson.get("choices");

            if (choices != null && choices.isArray() && choices.size() > 0) {
                String content = choices.get(0).get("message").get("content").asText().trim();
                if (content.startsWith("```")) {
                    content = content.replaceAll("^```(?:json)?\\s*", "").replaceAll("```\\s*$", "").trim();
                }
                return content;
            }

            log.warn("OpenAI Vision returned no choices");
            return null;
        } catch (Exception e) {
            log.error("Failed to analyze verification document: {}", e.getMessage());
            return null;
        }
    }

    public String analyzeOrganiserVerification(String organiserName, String email, String bio, String website,
                                                 String contactEmail, String contactPhone, boolean verified,
                                                 int totalEvents, int totalFollowers, long approvedEvents,
                                                 long pendingEvents, long rejectedEvents, long totalRegistrations,
                                                 Double averageRating, long reviewCount, long accountAgeDays,
                                                 boolean hasValidDocument) {
        String systemPrompt = """
            You are an AI verification assistant for an event management platform. Analyse an event organiser's
            profile and activity to help the admin decide whether to trust them.

            STRICT LANGUAGE RULE: Respond in ENGLISH ONLY. Never use Vietnamese or any other language.
            Every field, every string, every list item MUST be English.

            Decision taxonomy:
            - trust: "HIGH" | "MEDIUM" | "LOW" (overall trustworthiness)
            - trustworthy: true | false (simple yes/no for the admin)
            - decision: "APPROVE" | "REJECT" | "REVIEW" (recommendation only — the admin has final authority)
            - confidence: 0-100 integer (how sure you are)

            Guidelines:
            1. Higher trust when: complete profile, valid documents, active history, positive reviews, older account.
            2. Lower trust when: missing fields, zero events/followers, new account with no activity, flagged signals.
            3. Keep "summary" to one sentence. Keep each bullet short (<= 12 words).
            4. Strengths lists what supports approval. Missing info lists concrete gaps (empty bio, no website, etc.).
            5. Risk signals flag anything suspicious (brand-new account, no contact info, etc.). Empty array if none.
            6. "recommendation" is a one-sentence closing note for the admin.
            7. Return ONLY valid JSON. No markdown, no extra text.

            JSON format (all values in English):
            {
              "trust": "HIGH",
              "trustworthy": true,
              "decision": "APPROVE",
              "confidence": 90,
              "summary": "Complete profile, strong track record, no risk indicators.",
              "strengths": ["Full profile information", "Active event history", "Positive attendee reviews"],
              "missingInfo": [],
              "riskSignals": [],
              "recommendation": "Safe to approve; organiser meets all trust criteria."
            }
            """;

        StringBuilder userPrompt = new StringBuilder();
        userPrompt.append("Analyse this organiser profile and activity. Respond in ENGLISH ONLY.\n\n");
        userPrompt.append("=== ORGANISER PROFILE ===\n");
        userPrompt.append("Name: ").append(organiserName != null ? organiserName : "(missing)").append("\n");
        userPrompt.append("Email: ").append(email != null ? email : "(missing)").append("\n");
        userPrompt.append("Bio: ").append(bio != null && !bio.isBlank() ? bio : "(missing)").append("\n");
        userPrompt.append("Website: ").append(website != null && !website.isBlank() ? website : "(missing)").append("\n");
        userPrompt.append("Contact email: ").append(contactEmail != null && !contactEmail.isBlank() ? contactEmail : "(missing)").append("\n");
        userPrompt.append("Contact phone: ").append(contactPhone != null && !contactPhone.isBlank() ? contactPhone : "(missing)").append("\n");
        userPrompt.append("Verified badge: ").append(verified ? "yes" : "no").append("\n");
        userPrompt.append("Valid verification document on file: ").append(hasValidDocument ? "yes" : "no").append("\n");
        userPrompt.append("\n=== ACTIVITY METRICS ===\n");
        userPrompt.append("Account age (days): ").append(accountAgeDays).append("\n");
        userPrompt.append("Total events: ").append(totalEvents).append("\n");
        userPrompt.append("  - Approved/published: ").append(approvedEvents).append("\n");
        userPrompt.append("  - Pending: ").append(pendingEvents).append("\n");
        userPrompt.append("  - Rejected: ").append(rejectedEvents).append("\n");
        userPrompt.append("Total followers: ").append(totalFollowers).append("\n");
        userPrompt.append("Total registrations received: ").append(totalRegistrations).append("\n");
        userPrompt.append("Average review rating: ").append(averageRating != null ? String.format("%.2f/5", averageRating) : "no reviews yet").append("\n");
        userPrompt.append("Total review count: ").append(reviewCount).append("\n");
        userPrompt.append("\nReturn ONLY valid JSON in English. Do not use Vietnamese.");

        return callOpenAiApi(systemPrompt, userPrompt.toString(), 600);
    }

    public String analyzeUserRisk(String fullName, String email, String role, String status,
                                   boolean emailVerified, boolean phoneVerified, long accountAgeDays,
                                   long totalRegistrations, long approvedRegistrations,
                                   long checkedInCount, long reviewCount,
                                   long flaggedReviewCount, long reportedCount) {
        String systemPrompt = """
            You are an AI risk-analysis assistant for a platform admin. Review a user's behaviour and data to
            suggest a moderation direction. The admin makes the final call.

            STRICT LANGUAGE RULE: Respond in ENGLISH ONLY. Never use Vietnamese or any other language.
            Every field, every string, every list item MUST be English.

            Decision taxonomy:
            - risk: "LOW" | "MEDIUM" | "HIGH"
            - action: "KEEP" | "WARN" | "LOCK" (recommendation — admin decides)
            - confidence: 0-100 integer

            Guidelines:
            1. Low risk: normal activity, no flags, verified contacts, no abusive reviews.
            2. Medium risk: unusual patterns, unverified contacts, some flagged content, brand-new account.
            3. High risk: multiple flagged reviews, many reports against them, suspicious behaviour.
            4. A brand-new account with zero activity is usually LOW risk with a "keep but monitor" note.
            5. Keep summary and each bullet short (<= 14 words).
            6. Return ONLY valid JSON. No markdown, no extra text.

            JSON format (all values in English):
            {
              "risk": "LOW",
              "action": "KEEP",
              "confidence": 75,
              "behaviorSummary": "New user, no transactions or reviews yet.",
              "reasons": ["No transactions yet", "No reviews yet", "New account"],
              "recommendation": "New user — monitor future activity, no action needed now."
            }
            """;

        StringBuilder userPrompt = new StringBuilder();
        userPrompt.append("Analyse this user's risk profile. Respond in ENGLISH ONLY.\n\n");
        userPrompt.append("=== USER ===\n");
        userPrompt.append("Name: ").append(fullName != null ? fullName : "(missing)").append("\n");
        userPrompt.append("Email: ").append(email != null ? email : "(missing)").append("\n");
        userPrompt.append("Role: ").append(role).append("\n");
        userPrompt.append("Account status: ").append(status).append("\n");
        userPrompt.append("Email verified: ").append(emailVerified ? "yes" : "no").append("\n");
        userPrompt.append("Phone verified: ").append(phoneVerified ? "yes" : "no").append("\n");
        userPrompt.append("Account age (days): ").append(accountAgeDays).append("\n");
        userPrompt.append("\n=== ACTIVITY ===\n");
        userPrompt.append("Total registrations: ").append(totalRegistrations).append("\n");
        userPrompt.append("Approved registrations: ").append(approvedRegistrations).append("\n");
        userPrompt.append("Check-ins: ").append(checkedInCount).append("\n");
        userPrompt.append("Reviews written: ").append(reviewCount).append("\n");
        userPrompt.append("\n=== RISK INDICATORS ===\n");
        userPrompt.append("Flagged reviews authored by this user: ").append(flaggedReviewCount).append("\n");
        userPrompt.append("Times reported by others: ").append(reportedCount).append("\n");
        userPrompt.append("\nReturn ONLY valid JSON in English. Do not use Vietnamese.");

        return callOpenAiApi(systemPrompt, userPrompt.toString(), 500);
    }

    private String callOpenAiApi(String systemPrompt, String userPrompt, int maxTokens) {
        try {
            log.info("=== Starting OpenAI API Call ===");
            log.info("Model: {}", model);
            log.info("Max tokens: {}", maxTokens);
            log.info("RestTemplate: {}", restTemplate != null ? "✅ Initialized" : "❌ NULL");

            if (restTemplate == null) {
                throw new RuntimeException("RestTemplate is not properly initialized!");
            }

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
            log.debug("OpenAI Request JSON: {} chars", requestJson.length());

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);

            HttpEntity<String> entity = new HttpEntity<>(requestJson, headers);

            log.info("Making POST request to: {}", OPENAI_API_URL);
            String responseStr = restTemplate.postForObject(OPENAI_API_URL, entity, String.class);
            log.info("✅ Received response from OpenAI API: {} chars", responseStr != null ? responseStr.length() : "null");

            if (responseStr == null) {
                log.error("❌ OpenAI API returned null response!");
                throw new RuntimeException("OpenAI API returned null response. Check if API key is valid.");
            }

            JsonNode responseJson = objectMapper.readTree(responseStr);
            JsonNode choices = responseJson.get("choices");

            if (choices != null && choices.isArray() && choices.size() > 0) {
                String result = choices.get(0).get("message").get("content").asText().trim();
                log.info("✅ Successfully extracted AI response: {} chars", result.length());
                return result;
            }

            log.warn("⚠️ No valid choices in OpenAI response. Full response: {}", responseStr);
            return "Unable to generate content. Please try again.";
        } catch (org.springframework.web.client.HttpClientErrorException e) {
            log.error("❌ HTTP Client Error: status={}, message={}, body={}",
                e.getStatusCode(), e.getMessage(), e.getResponseBodyAsString());
            if (e.getStatusCode().value() == 401 || e.getStatusCode().value() == 403) {
                String msg = "OpenAI API authentication failed: Invalid or missing API key. Status: " + e.getStatusCode();
                throw new RuntimeException(msg);
            }
            String msg = "OpenAI API Error: " + e.getStatusCode() + " - " + (e.getMessage() != null ? e.getMessage() : "No details");
            throw new RuntimeException(msg);
        } catch (org.springframework.web.client.HttpServerErrorException e) {
            log.error("❌ HTTP Server Error: status={}, message={}, body={}",
                e.getStatusCode(), e.getMessage(), e.getResponseBodyAsString());
            String msg = "OpenAI API Server Error: " + e.getStatusCode() + " - " + (e.getMessage() != null ? e.getMessage() : "No details");
            throw new RuntimeException(msg);
        } catch (Exception e) {
            log.error("❌ Unexpected error calling OpenAI API: ", e);
            String errorDetail = e.getMessage() != null ? e.getMessage() : e.getClass().getSimpleName();
            String msg = "Failed to generate AI content: " + errorDetail;
            throw new RuntimeException(msg);
        }
    }
}
