package com.luma.validation;

import jakarta.validation.Constraint;
import jakarta.validation.Payload;
import java.lang.annotation.*;

/**
 * Validates event time constraints:
 * - Start time must be in the future
 * - End time must be after start time
 * - Registration deadline must be before start time (if provided)
 */
@Documented
@Constraint(validatedBy = EventTimeValidator.class)
@Target({ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
public @interface ValidEventTime {

    String message() default "Invalid event time configuration";

    Class<?>[] groups() default {};

    Class<? extends Payload>[] payload() default {};
}
