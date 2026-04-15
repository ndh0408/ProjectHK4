package com.luma.config;

import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.ClientHttpResponse;
import org.springframework.web.client.ResponseErrorHandler;
import org.springframework.web.client.RestTemplate;

import java.io.IOException;

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
    public RestTemplate groqRestTemplate(RestTemplateBuilder builder) {
        return builder
                .errorHandler(new ResponseErrorHandler() {
                    @Override
                    public boolean hasError(ClientHttpResponse response) throws IOException {
                        return response.getStatusCode().isError();
                    }

                    @Override
                    public void handleError(ClientHttpResponse response) throws IOException {
                        String body = "No response body";
                        try {
                            byte[] bytes = response.getBody().readAllBytes();
                            body = new String(bytes);
                        } catch (Exception e) {
                            log.debug("Could not read response body", e);
                        }
                        log.error("Groq API Error: {} - {}", response.getStatusCode(), body);
                        
                        // Throw exception so it can be caught and handled properly
                        throw new org.springframework.web.client.HttpClientErrorException(
                            response.getStatusCode(),
                            "Groq API Error: " + body
                        );
                    }
                })
                .interceptors((request, body, execution) -> {
                    if (apiKey != null && !apiKey.isBlank()) {
                        request.getHeaders().set("Authorization", "Bearer " + apiKey);
                        log.debug("Authorization header added to Groq API request");
                    } else {
                        log.warn("⚠️ No Groq API key available for request!");
                    }
                    return execution.execute(request, body);
                })
                .build();
    }
}

