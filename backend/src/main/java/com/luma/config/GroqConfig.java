package com.luma.config;

import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestTemplate;

@Configuration
@Slf4j
public class GroqConfig {

    @Value("${groq.api-key:}")
    private String apiKey;

    @PostConstruct
    public void validateApiKey() {
        if (apiKey == null || apiKey.isBlank() || "your-groq-api-key-here".equals(apiKey)) {
            log.warn("⚠️  GROQ_API_KEY is not configured! AI features will fail. " +
                    "Set the GROQ_API_KEY environment variable or groq.api-key property.");
        } else {
            log.info("✅ Groq API key configured successfully");
        }
    }

    @Bean
    public RestTemplate groqRestTemplate() {
        RestTemplate restTemplate = new RestTemplate();
        restTemplate.getInterceptors().add((request, body, execution) -> {
            if (apiKey != null && !apiKey.isBlank()) {
                request.getHeaders().set("Authorization", "Bearer " + apiKey);
            }
            return execution.execute(request, body);
        });
        return restTemplate;
    }
}
