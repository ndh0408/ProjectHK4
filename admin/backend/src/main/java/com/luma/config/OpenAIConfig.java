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
public class OpenAIConfig {

    @Value("${openai.api-key:}")
    private String apiKey;

    @PostConstruct
    public void validateApiKey() {
        if (apiKey == null || apiKey.isBlank() || "your-openai-api-key-here".equals(apiKey)) {
            log.warn("⚠️  OPENAI_API_KEY is not configured! AI features will fail. " +
                    "Set the OPENAI_API_KEY environment variable or openai.api-key property.");
        } else {
            log.info("✅ OpenAI API key configured successfully");
        }
    }

    @Bean
    public RestTemplate openaiRestTemplate(RestTemplateBuilder builder) {
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
                        log.error("OpenAI API Error: {} - {}", response.getStatusCode(), body);

                        throw new org.springframework.web.client.HttpClientErrorException(
                            response.getStatusCode(),
                            "OpenAI API Error: " + body
                        );
                    }
                })
                .interceptors((request, body, execution) -> {
                    if (apiKey != null && !apiKey.isBlank()) {
                        request.getHeaders().set("Authorization", "Bearer " + apiKey);
                        log.debug("Authorization header added to OpenAI API request");
                    } else {
                        log.warn("⚠️ No OpenAI API key available for request!");
                    }
                    return execution.execute(request, body);
                })
                .build();
    }
}
