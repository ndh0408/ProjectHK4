package com.luma.dto.request;

import lombok.Data;

@Data
public class UpdateProfileRequest {

    private String fullName;

    private String phone;

    private String avatarUrl;

    private String signatureUrl;

    private Boolean emailNotificationsEnabled;

    private Boolean emailEventReminders;

    private String bio;

    private String interests;

    private Boolean networkingVisible;
}
