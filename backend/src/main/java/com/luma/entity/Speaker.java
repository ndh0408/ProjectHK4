package com.luma.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "speakers")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Speaker {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    private String title; // Job title, e.g., "CEO at TechCorp"

    @Column(columnDefinition = "NVARCHAR(MAX)")
    private String bio; // Short biography

    private String imageUrl; // Profile photo

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "event_id", nullable = false)
    private Event event;
}
