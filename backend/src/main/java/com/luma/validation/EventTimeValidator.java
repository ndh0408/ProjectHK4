package com.luma.validation;

import com.luma.dto.request.EventCreateRequest;
import com.luma.dto.request.EventUpdateRequest;
import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;

import java.time.LocalDateTime;

/**
 * Validator for event time constraints
 */
public class EventTimeValidator implements ConstraintValidator<ValidEventTime, Object> {

    @Override
    public void initialize(ValidEventTime constraintAnnotation) {
        // No initialization needed
    }

    @Override
    public boolean isValid(Object value, ConstraintValidatorContext context) {
        if (value == null) {
            return true;
        }

        LocalDateTime startTime;
        LocalDateTime endTime;
        LocalDateTime registrationDeadline;
        boolean isUpdate = false;

        if (value instanceof EventCreateRequest request) {
            startTime = request.getStartTime();
            endTime = request.getEndTime();
            registrationDeadline = request.getRegistrationDeadline();
        } else if (value instanceof EventUpdateRequest request) {
            startTime = request.getStartTime();
            endTime = request.getEndTime();
            registrationDeadline = request.getRegistrationDeadline();
            isUpdate = true;
        } else {
            return true;
        }

        // Disable default constraint violation
        context.disableDefaultConstraintViolation();
        boolean isValid = true;

        // Validate start time is in the future (only for new events)
        if (!isUpdate && startTime != null && startTime.isBefore(LocalDateTime.now())) {
            context.buildConstraintViolationWithTemplate("Start time must be in the future")
                   .addPropertyNode("startTime")
                   .addConstraintViolation();
            isValid = false;
        }

        // Validate end time is after start time
        if (startTime != null && endTime != null && !endTime.isAfter(startTime)) {
            context.buildConstraintViolationWithTemplate("End time must be after start time")
                   .addPropertyNode("endTime")
                   .addConstraintViolation();
            isValid = false;
        }

        // Validate registration deadline is before or equal to start time
        if (registrationDeadline != null && startTime != null && registrationDeadline.isAfter(startTime)) {
            context.buildConstraintViolationWithTemplate("Registration deadline must be before or at event start time")
                   .addPropertyNode("registrationDeadline")
                   .addConstraintViolation();
            isValid = false;
        }

        // Validate registration deadline is in the future (for new events)
        if (!isUpdate && registrationDeadline != null && registrationDeadline.isBefore(LocalDateTime.now())) {
            context.buildConstraintViolationWithTemplate("Registration deadline must be in the future")
                   .addPropertyNode("registrationDeadline")
                   .addConstraintViolation();
            isValid = false;
        }

        // Validate event duration is reasonable (max 30 days)
        if (startTime != null && endTime != null) {
            long daysBetween = java.time.Duration.between(startTime, endTime).toDays();
            if (daysBetween > 30) {
                context.buildConstraintViolationWithTemplate("Event duration cannot exceed 30 days")
                       .addPropertyNode("endTime")
                       .addConstraintViolation();
                isValid = false;
            }
        }

        return isValid;
    }
}
