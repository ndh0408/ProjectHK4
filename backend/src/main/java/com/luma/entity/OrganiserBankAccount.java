package com.luma.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "organiser_bank_accounts")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OrganiserBankAccount {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "organiser_id", nullable = false, unique = true)
    private User organiser;

    @Column(length = 100)
    private String stripeAccountId;

    @Column(length = 50)
    private String accountStatus; // not_created, pending, verified, restricted

    @Column(length = 100)
    private String bankName;

    @Column(length = 20)
    private String lastFourDigits;

    @Column(length = 10)
    private String currency;

    @Column(length = 50)
    private String country;

    @Builder.Default
    private Boolean payoutsEnabled = false;

    @Builder.Default
    private Boolean chargesEnabled = false;

    private LocalDateTime verifiedAt;

    @CreationTimestamp
    private LocalDateTime createdAt;

    @UpdateTimestamp
    private LocalDateTime updatedAt;
}
