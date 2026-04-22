package com.luma.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.Environment;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.context.event.ApplicationStartedEvent;
import org.springframework.context.event.EventListener;

/**
 * Environment Configuration - loads and verifies .env file settings
 * The spring-dotenv library automatically loads .env files from the classpath/project root
 */
@Slf4j
@Configuration
public class EnvConfig {

    @Autowired
    private Environment environment;

    @EventListener(ApplicationStartedEvent.class)
    public void onApplicationStarted() {
        // Verify environment variables loaded after application starts
        String openaiApiKey = environment.getProperty("openai.api-key");
        String openaiModel = environment.getProperty("openai.model");

        if (openaiApiKey != null && !openaiApiKey.isBlank() && !openaiApiKey.equals("${OPENAI_API_KEY}")) {
            log.info("✅ OpenAI API configured successfully - Model: {}", openaiModel);
        } else {
            log.warn("⚠️  OPENAI_API_KEY environment variable not found");
            log.info("📝 Verify .env file exists in 'backend' directory with: OPENAI_API_KEY=sk-...");
        }
    }
}
