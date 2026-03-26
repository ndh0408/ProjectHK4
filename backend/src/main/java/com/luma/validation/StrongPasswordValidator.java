package com.luma.validation;

import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;

import java.util.regex.Pattern;

/**
 * Validator cho StrongPassword annotation
 */
public class StrongPasswordValidator implements ConstraintValidator<StrongPassword, String> {

    // Tối thiểu 8 ký tự
    private static final int MIN_LENGTH = 8;

    // Patterns cho từng yêu cầu
    private static final Pattern UPPERCASE_PATTERN = Pattern.compile("[A-Z]");
    private static final Pattern LOWERCASE_PATTERN = Pattern.compile("[a-z]");
    private static final Pattern DIGIT_PATTERN = Pattern.compile("[0-9]");
    private static final Pattern SPECIAL_CHAR_PATTERN = Pattern.compile("[!@#$%^&*()_+\\-=\\[\\]{};':\"\\\\|,.<>/?]");

    @Override
    public void initialize(StrongPassword constraintAnnotation) {
        // Không cần khởi tạo gì đặc biệt
    }

    @Override
    public boolean isValid(String password, ConstraintValidatorContext context) {
        // Null được handle bởi @NotBlank
        if (password == null) {
            return true;
        }

        StringBuilder errors = new StringBuilder();
        boolean isValid = true;

        // Check độ dài tối thiểu
        if (password.length() < MIN_LENGTH) {
            errors.append("Password must be at least ").append(MIN_LENGTH).append(" characters. ");
            isValid = false;
        }

        // Check chữ hoa
        if (!UPPERCASE_PATTERN.matcher(password).find()) {
            errors.append("Must contain at least one uppercase letter. ");
            isValid = false;
        }

        // Check chữ thường
        if (!LOWERCASE_PATTERN.matcher(password).find()) {
            errors.append("Must contain at least one lowercase letter. ");
            isValid = false;
        }

        // Check số
        if (!DIGIT_PATTERN.matcher(password).find()) {
            errors.append("Must contain at least one digit. ");
            isValid = false;
        }

        // Check ký tự đặc biệt
        if (!SPECIAL_CHAR_PATTERN.matcher(password).find()) {
            errors.append("Must contain at least one special character (!@#$%^&*...). ");
            isValid = false;
        }

        // Nếu không hợp lệ, set custom message
        if (!isValid) {
            context.disableDefaultConstraintViolation();
            context.buildConstraintViolationWithTemplate(errors.toString().trim())
                   .addConstraintViolation();
        }

        return isValid;
    }
}
