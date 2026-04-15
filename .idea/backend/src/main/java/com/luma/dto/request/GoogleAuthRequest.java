package com.luma.dto.request;

import lombok.Data;

@Data
public class GoogleAuthRequest {

    private String idToken;

    private String accessToken;
    private String email;
    private String fullName;
    private String avatarUrl;
}
