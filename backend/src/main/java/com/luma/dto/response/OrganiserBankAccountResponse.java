package com.luma.dto.response;

import com.luma.entity.OrganiserBankAccount;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OrganiserBankAccountResponse {

    private UUID id;
    private UUID organiserId;
    private String accountStatus;
    private String bankName;
    private String lastFourDigits;
    private String currency;
    private String country;
    private Boolean payoutsEnabled;
    private Boolean chargesEnabled;
    private LocalDateTime verifiedAt;
    private LocalDateTime createdAt;

    private String onboardingUrl;

    public static OrganiserBankAccountResponse fromEntity(OrganiserBankAccount account) {
        return OrganiserBankAccountResponse.builder()
                .id(account.getId())
                .organiserId(account.getOrganiser().getId())
                .accountStatus(account.getAccountStatus())
                .bankName(account.getBankName())
                .lastFourDigits(account.getLastFourDigits())
                .currency(account.getCurrency())
                .country(account.getCountry())
                .payoutsEnabled(account.getPayoutsEnabled())
                .chargesEnabled(account.getChargesEnabled())
                .verifiedAt(account.getVerifiedAt())
                .createdAt(account.getCreatedAt())
                .build();
    }
}
