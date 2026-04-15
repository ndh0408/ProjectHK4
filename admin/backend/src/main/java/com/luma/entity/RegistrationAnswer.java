package com.luma.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "registration_answers")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RegistrationAnswer {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "registration_id", nullable = false)
    private Registration registration;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "question_id", nullable = false)
    private RegistrationQuestion question;

    @Column(columnDefinition = "NVARCHAR(MAX)")
    private String answerText;

    @CreationTimestamp
    private LocalDateTime createdAt;
}
