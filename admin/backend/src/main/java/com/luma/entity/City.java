package com.luma.entity;

import jakarta.persistence.*;
import lombok.*;

import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "cities")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class City {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    private String country;

    private String continent;

    private String imageUrl;

    private Double latitude;

    private Double longitude;

    @Column(nullable = false)
    @Builder.Default
    private boolean active = true;

    @OneToMany(mappedBy = "city", fetch = FetchType.LAZY)
    @Builder.Default
    private List<Event> events = new ArrayList<>();
}
