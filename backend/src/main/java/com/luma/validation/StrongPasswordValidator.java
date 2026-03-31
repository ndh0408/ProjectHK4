package com.luma.validation;

import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;

import java.util.regex.Pattern;

public class StrongPasswordValidator implements ConstraintValidator<StrongPassword, String> {

    private static final int MIN_LENGTH = 8;

    private static final Pattern UPPERCASE_PATTERN = Pattern.compile("[A-Z]");
    private static final Pattern LOWERCASE_PATTERN = Pattern.compile("[a-z]");
    private static final Pattern DIGIT_PATTERN = Pattern.compile("[0-9]");
    private static final Pattern SPECIAL_CHAR_PATTERN = Pattern.compile("[!@#$%^&*()_+\\-=\\[\\]{};':\"\\\\|,.<>/?]");

    @Override
    public void initialize(StrongPassword constraintAnnotation) {
    }

    @Override
    public boolean isValid(String password, ConstraintValidatorContext context) {
        if (password == null) {
            return true;
        }

        StringBuilder errors = new StringBuilder();
        boolean isValid = true;

        if (password.length() < MIN_LENGTH) {
            errors.append("Password must be at least ").append(MIN_LENGTH).append(" characters. ");
            isValid = false;
        }

        if (!UPPERCASE_PATTERN.matcher(password).find()) {
            errors.append("Must contain at least one uppercase letter. ");
            isValid = false;
        }

        if (!LOWERCASE_PATTERN.matcher(password).find()) {
            errors.append("Must contain at least one lowercase letter. ");
            isValid = false;
        }

        if (!DIGIT_PATTERN.matcher(password).find()) {
            errors.append("Must contain at least one digit. ");
            isValid = false;
        }

        if (!SPECIAL_CHAR_PATTERN.matcher(password).find()) {
            errors.append("Must contain at least one special character (!@#$%^&*...). ");
            isValid = false;
        }

        if (!isValid) {
            context.disableDefaultConstraintViolation();
            context.buildConstraintViolationWithTemplate(errors.toString().trim())
                   .addConstraintViolation();
        }

        return isValid;
    }
}
