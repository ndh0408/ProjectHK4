package com.luma.dto.request.userboost;

import com.luma.entity.enums.UserBoostPackage;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class CreateUserBoostRequest {

    @NotNull(message = "Event ID is required")
    private UUID eventId;

    @NotNull(message = "Boost package is required")
    private UserBoostPackage boostPackage;
}
