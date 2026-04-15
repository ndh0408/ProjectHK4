package com.luma.service;

import com.cloudinary.Cloudinary;
import com.cloudinary.utils.ObjectUtils;
import com.luma.exception.BadRequestException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.Map;

@Service
@RequiredArgsConstructor
@Slf4j
public class CloudinaryService {

    private final Cloudinary cloudinary;

    private static final long MAX_FILE_SIZE = 10 * 1024 * 1024;
    private static final String[] ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"};

    public String uploadImage(MultipartFile file, String folder) {
        validateFile(file);

        try {
            Map<String, Object> options = ObjectUtils.asMap(
                    "folder", folder,
                    "resource_type", "image"
            );

            Map<?, ?> result = cloudinary.uploader().upload(file.getBytes(), options);
            String secureUrl = (String) result.get("secure_url");
            log.info("Image uploaded successfully: {}", secureUrl);
            return secureUrl;
        } catch (IOException e) {
            log.error("Failed to upload image to Cloudinary", e);
            throw new BadRequestException("Failed to upload image. Please try again.");
        }
    }

    public void deleteImage(String publicId) {
        try {
            cloudinary.uploader().destroy(publicId, ObjectUtils.emptyMap());
            log.info("Image deleted successfully: {}", publicId);
        } catch (IOException e) {
            log.error("Failed to delete image from Cloudinary", e);
        }
    }

    private void validateFile(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new BadRequestException("File is required");
        }

        if (file.getSize() > MAX_FILE_SIZE) {
            throw new BadRequestException("File size must be less than 10MB");
        }

        String contentType = file.getContentType();
        boolean isValidType = false;
        for (String type : ALLOWED_TYPES) {
            if (type.equals(contentType)) {
                isValidType = true;
                break;
            }
        }

        if (!isValidType) {
            throw new BadRequestException("Invalid file type. Allowed: JPG, PNG, WebP, GIF");
        }
    }
}
