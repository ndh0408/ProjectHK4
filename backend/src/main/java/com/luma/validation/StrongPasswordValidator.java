package com.luma.validation;

import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;

public class StrongPasswordValidator implements ConstraintValidator<StrongPassword, String> {

    private static final int MIN_LENGTH = 8;

    @Override
    public void initialize(StrongPassword constraintAnnotation) {
    }

    @Override
    public boolean isValid(String password, ConstraintValidatorContext context) {
        if (password == null) {
            return true;
        }

        context.disableDefaultConstraintViolation();

        if (password.length() < MIN_LENGTH) {
            context.buildConstraintViolationWithTemplate(
                    "Password must be at least " + MIN_LENGTH + " characters")
                   .addConstraintViolation();
            return false;
        }

        if (!password.matches(".*[A-Z].*")) {
            context.buildConstraintViolationWithTemplate(
                    "Password must contain at least one uppercase letter")
                   .addConstraintViolation();
            return false;
        }

        if (!password.matches(".*[a-z].*")) {
            context.buildConstraintViolationWithTemplate(
                    "Password must contain at least one lowercase letter")
                   .addConstraintViolation();
            return false;
        }

        if (!password.matches(".*[0-9].*")) {
            context.buildConstraintViolationWithTemplate(
                    "Password must contain at least one digit")
                   .addConstraintViolation();
            return false;
        }

        return true;
    }
}
