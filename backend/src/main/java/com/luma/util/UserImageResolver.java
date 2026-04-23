package com.luma.util;

import com.luma.entity.OrganiserProfile;
import com.luma.entity.User;

public final class UserImageResolver {

    private UserImageResolver() {
    }

    public static String resolve(User user) {
        if (user == null) {
            return null;
        }

        OrganiserProfile organiserProfile = user.getOrganiserProfile();
        if (organiserProfile != null) {
            String organiserLogo = organiserProfile.getLogoUrl();
            if (hasText(organiserLogo)) {
                return organiserLogo;
            }
        }

        if (hasText(user.getAvatarUrl())) {
            return user.getAvatarUrl();
        }

        if (organiserProfile != null && hasText(organiserProfile.getCoverUrl())) {
            return organiserProfile.getCoverUrl();
        }

        return null;
    }

    private static boolean hasText(String value) {
        return value != null && !value.isBlank();
    }
}
