package com.utility.billing.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "tariff_tiers")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TariffTier {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "tariff_id", nullable = false)
    private Tariff tariff;

    @Column(name = "min_consumption", nullable = false)
    private Double minConsumption;

    @Column(name = "max_consumption")
    private Double maxConsumption;

    @Column(nullable = false)
    private Double rate;

    private String description;
}
