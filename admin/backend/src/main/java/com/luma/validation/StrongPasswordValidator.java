package com.luma.validation;

import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;

public class StrongPasswordValidator implements ConstraintValidator<StrongPassword, String> {

    private static final int MIN_LENGTH = 6;

    @Override
    public void initialize(StrongPassword constraintAnnotation) {
    }

    @Override
    public boolean isValid(String password, ConstraintValidatorContext context) {
        if (password == null) {
            return true;
        }

        if (password.length() < MIN_LENGTH) {
            context.disableDefaultConstraintViolation();
            context.buildConstraintViolationWithTemplate(
                    "Password must be at least " + MIN_LENGTH + " characters")
                   .addConstraintViolation();
            return false;
        }

        return true;
    }
}
