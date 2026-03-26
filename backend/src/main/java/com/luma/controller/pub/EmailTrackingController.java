package com.luma.controller.pub;

import com.luma.service.EmailMarketingService;
import io.swagger.v3.oas.annotations.Hidden;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/email")
@RequiredArgsConstructor
@Hidden // Hide from Swagger
public class EmailTrackingController {

    private final EmailMarketingService emailMarketingService;

    // 1x1 transparent GIF
    private static final byte[] TRACKING_PIXEL = {
        0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00,
        (byte) 0x80, 0x00, 0x00, (byte) 0xff, (byte) 0xff, (byte) 0xff,
        0x00, 0x00, 0x00, 0x21, (byte) 0xf9, 0x04, 0x01, 0x00, 0x00,
        0x00, 0x00, 0x2c, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01,
        0x00, 0x00, 0x02, 0x02, 0x44, 0x01, 0x00, 0x3b
    };

    @GetMapping("/track/open/{recipientId}")
    public ResponseEntity<byte[]> trackOpen(@PathVariable UUID recipientId) {
        try {
            emailMarketingService.trackOpen(recipientId);
        } catch (Exception e) {
            // Silently ignore tracking errors
        }

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.IMAGE_GIF);
        headers.setCacheControl("no-cache, no-store, must-revalidate");

        return new ResponseEntity<>(TRACKING_PIXEL, headers, HttpStatus.OK);
    }

    @GetMapping("/track/click/{recipientId}")
    public ResponseEntity<Void> trackClick(
            @PathVariable UUID recipientId,
            @RequestParam String redirect) {
        try {
            emailMarketingService.trackClick(recipientId);
        } catch (Exception e) {
            // Silently ignore tracking errors
        }

        HttpHeaders headers = new HttpHeaders();
        headers.add("Location", redirect);

        return new ResponseEntity<>(headers, HttpStatus.FOUND);
    }

    @GetMapping("/unsubscribe/{recipientId}")
    public ResponseEntity<String> showUnsubscribePage(@PathVariable UUID recipientId) {
        String html = """
            <!DOCTYPE html>
            <html>
            <head>
                <title>Unsubscribe - LUMA</title>
                <style>
                    body { font-family: Arial, sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background: #f5f5f5; }
                    .container { background: white; padding: 40px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); text-align: center; max-width: 400px; }
                    h1 { color: #333; margin-bottom: 20px; }
                    p { color: #666; margin-bottom: 20px; }
                    textarea { width: 100%; padding: 10px; border: 1px solid #ddd; border-radius: 4px; margin-bottom: 20px; }
                    button { background: #6366f1; color: white; border: none; padding: 12px 24px; border-radius: 4px; cursor: pointer; font-size: 16px; }
                    button:hover { background: #5558e3; }
                </style>
            </head>
            <body>
                <div class="container">
                    <h1>Unsubscribe</h1>
                    <p>We're sorry to see you go. Please let us know why you're unsubscribing (optional):</p>
                    <form action="/api/email/unsubscribe/%s" method="POST">
                        <textarea name="reason" rows="3" placeholder="Your feedback (optional)"></textarea>
                        <button type="submit">Unsubscribe</button>
                    </form>
                </div>
            </body>
            </html>
            """.formatted(recipientId);

        return ResponseEntity.ok()
                .contentType(MediaType.TEXT_HTML)
                .body(html);
    }

    @PostMapping("/unsubscribe/{recipientId}")
    public ResponseEntity<String> handleUnsubscribe(
            @PathVariable UUID recipientId,
            @RequestParam(required = false) String reason) {
        try {
            emailMarketingService.handleUnsubscribe(recipientId, reason);
        } catch (Exception e) {
            // Silently ignore errors
        }

        String html = """
            <!DOCTYPE html>
            <html>
            <head>
                <title>Unsubscribed - LUMA</title>
                <style>
                    body { font-family: Arial, sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background: #f5f5f5; }
                    .container { background: white; padding: 40px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); text-align: center; max-width: 400px; }
                    h1 { color: #333; margin-bottom: 20px; }
                    p { color: #666; }
                    .checkmark { font-size: 48px; color: #10b981; margin-bottom: 20px; }
                </style>
            </head>
            <body>
                <div class="container">
                    <div class="checkmark">✓</div>
                    <h1>You've been unsubscribed</h1>
                    <p>You will no longer receive marketing emails from LUMA. You may still receive transactional emails related to your account and event registrations.</p>
                </div>
            </body>
            </html>
            """;

        return ResponseEntity.ok()
                .contentType(MediaType.TEXT_HTML)
                .body(html);
    }
}
