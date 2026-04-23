package com.luma.dto.request;

import com.luma.entity.enums.DevicePlatform;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class DeviceTokenRequest {

    @NotBlank
    @Size(max = 500)
    private String token;

    private DevicePlatform platform;

    @Size(max = 150)
    private String deviceModel;

    @Size(max = 50)
    private String appVersion;
}
