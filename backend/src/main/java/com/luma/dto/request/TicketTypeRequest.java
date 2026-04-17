package com.luma.dto.request;

import jakarta.validation.constraints.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TicketTypeRequest {

    private UUID id;

    @NotBlank(message = "Ticket name is required")
    @Size(max = 100, message = "Name must be less than 100 characters")
    private String name;

    @Size(max = 1000, message = "Description must be less than 1000 characters")
    private String description;

    @NotNull(message = "Price is required")
    @DecimalMin(value = "0.00", message = "Price must be greater than or equal to 0")
    @Digits(integer = 8, fraction = 2, message = "Price must have at most 8 integer digits and 2 decimal places")
    private BigDecimal price;

    @NotNull(message = "Quantity is required")
    @Min(value = 1, message = "Quantity must be at least 1")
    @Max(value = 100000, message = "Quantity must be at most 100,000")
    private Integer quantity;

    @Min(value = 1, message = "Max per order must be at least 1")
    @Max(value = 100, message = "Max per order must be at most 100")
    @Builder.Default
    private Integer maxPerOrder = 10;

    private LocalDateTime saleStartDate;

    private LocalDateTime saleEndDate;

    @Builder.Default
    private Boolean isVisible = true;

    private Integer displayOrder;
}
