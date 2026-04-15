package com.luma.dto.request.boost;

import com.luma.entity.enums.BoostPackage;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.UUID;

@Data
public class CreateBoostRequest {

    @NotNull(message = "Event ID is required")
    private UUID eventId;

    @NotNull(message = "Boost package is required")
    private BoostPackage boostPackage;
}
