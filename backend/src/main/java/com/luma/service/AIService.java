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

    private static final String GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions";

    public AIService(
            RestTemplate groqRestTemplate,
            @Value("${groq.model:llama-3.3-70b-versatile}") String model) {
        this.restTemplate = groqRestTemplate;
        this.model = model;
        this.objectMapper = new ObjectMapper();
        log.info("AIService initialized with Groq model: {}", model);
    }

    public String suggestAnswer(Question question) {
        Event event = question.getEvent();

        String systemPrompt = buildSystemPrompt(event);
        String userPrompt = buildUserPrompt(question);

        try {
            log.info("Calling Groq API with model: {}", model);

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
            log.debug("Groq Request JSON: {}", requestJson);

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);

            HttpEntity<String> entity = new HttpEntity<>(requestJson, headers);

            String responseStr = restTemplate.postForObject(GROQ_API_URL, entity, String.class);

            JsonNode responseJson = objectMapper.readTree(responseStr);
            JsonNode choices = responseJson.get("choices");

            if (choices != null && choices.isArray() && choices.size() > 0) {
                return choices.get(0).get("message").get("content").asText().trim();
            }

            return "Unable to generate suggestion. Please try again.";
        } catch (Exception e) {
            log.error("Error calling Groq API: ", e);
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

        return callGroqApi(systemPrompt, userPrompt.toString(), 800);
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

        return callGroqApi(systemPrompt, userPrompt, 800);
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

        return callGroqApi(systemPrompt, userPrompt.toString(), 200);
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

        return callGroqApi(systemPrompt, userPrompt.toString(), 300);
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

        return callGroqApi(systemPrompt, userPrompt.toString(), 1000);
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

        return callGroqApi(systemPrompt, userPrompt.toString(), 1000);
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

        return callGroqApi(systemPrompt, userPrompt.toString(), 800);
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

        return callGroqApi(systemPrompt, userPrompt.toString(), 300);
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

        return callGroqApi(systemPrompt, userPrompt.toString(), 300);
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

        return callGroqApi(systemPrompt, userPrompt.toString(), 1200);
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

        return callGroqApi(systemPrompt, userPrompt.toString(), 400);
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

        return callGroqApi(systemPrompt, userPrompt.toString(), 300);
    }

    public String generateFullEvent(String eventIdea, String eventType, String targetAudience,
                                     String preferredDate, String preferredTime, String cityName, String language) {
        String systemPrompt = """
            You are an expert event planner and marketing specialist. Your task is to generate a complete event proposal based on a simple idea.

            IMPORTANT RULES:
            1. Return ONLY valid JSON - no extra text before or after
            2. Language: Write in %s (Vietnamese if "vi", English if "en")
            3. Be creative but realistic
            4. Generate 3 different title options
            5. Description should be in Markdown format (150-250 words)
            6. Suggest realistic venue based on event type and city
            7. Capacity should match event type (workshop: 20-50, seminar: 50-200, conference: 100-500, meetup: 30-100, party: 50-300)
            8. Price: suggest FREE for community/networking events, paid for professional/premium events

            JSON format required:
            {
              "titleSuggestions": ["Title 1", "Title 2", "Title 3"],
              "description": "Markdown description here...",
              "suggestedCategory": "Technology/Business/Arts/Music/Sports/Education/Health/Food/Community/Other",
              "suggestedVenue": "Venue name suggestion",
              "suggestedAddress": "Full address suggestion",
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
            """.formatted(language.equals("vi") ? "Vietnamese" : "English");

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

        return callGroqApi(systemPrompt, userPrompt.toString(), 1500);
    }

    private String callGroqApi(String systemPrompt, String userPrompt, int maxTokens) {
        try {
            log.info("Calling Groq API with model: {}", model);

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
            log.debug("Groq Request JSON: {}", requestJson);

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);

            HttpEntity<String> entity = new HttpEntity<>(requestJson, headers);

            String responseStr = restTemplate.postForObject(GROQ_API_URL, entity, String.class);

            JsonNode responseJson = objectMapper.readTree(responseStr);
            JsonNode choices = responseJson.get("choices");

            if (choices != null && choices.isArray() && choices.size() > 0) {
                return choices.get(0).get("message").get("content").asText().trim();
            }

            return "Unable to generate content. Please try again.";
        } catch (Exception e) {
            log.error("Error calling Groq API: ", e);
            throw new RuntimeException("Failed to generate AI content: " + e.getMessage());
        }
    }
}
