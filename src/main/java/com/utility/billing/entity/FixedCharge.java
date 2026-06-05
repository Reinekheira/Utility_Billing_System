package com.utility.billing.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "fixed_charges")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FixedCharge {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "meter_type", nullable = false)
    @Enumerated(EnumType.STRING)
    private Meter.MeterType meterType;

    @Column(name = "charge_name", nullable = false)
    private String chargeName;

    @Column(nullable = false)
    private Double amount;

    @Column(nullable = false)
    private Integer version;

    @Column(name = "effective_from", nullable = false)
    private LocalDate effectiveFrom;

    @Column(name = "effective_to")
    private LocalDate effectiveTo;

    @Column(name = "is_active")
    private Boolean isActive;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;
}
