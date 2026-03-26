package com.luma.validation;

import jakarta.validation.Constraint;
import jakarta.validation.Payload;
import java.lang.annotation.*;

/**
 * Custom annotation để validate mật khẩu mạnh
 * Yêu cầu:
 * - Tối thiểu 8 ký tự
 * - Ít nhất 1 chữ hoa
 * - Ít nhất 1 chữ thường
 * - Ít nhất 1 số
 * - Ít nhất 1 ký tự đặc biệt
 */
@Documented
@Constraint(validatedBy = StrongPasswordValidator.class)
@Target({ElementType.FIELD, ElementType.PARAMETER})
@Retention(RetentionPolicy.RUNTIME)
public @interface StrongPassword {

    String message() default "Password must be at least 8 characters and contain uppercase, lowercase, number, and special character";

    Class<?>[] groups() default {};

    Class<? extends Payload>[] payload() default {};
}
