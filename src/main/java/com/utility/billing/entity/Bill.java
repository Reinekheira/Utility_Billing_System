package com.utility.billing.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "bills")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Bill {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "bill_number", nullable = false, unique = true)
    private String billNumber;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "customer_id", nullable = false)
    private Customer customer;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "meter_id", nullable = false)
    private Meter meter;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "meter_reading_id", nullable = false)
    private MeterReading meterReading;

    @Column(name = "billing_month", nullable = false)
    private Integer billingMonth;

    @Column(name = "billing_year", nullable = false)
    private Integer billingYear;

    @Column(nullable = false)
    private Double consumption;

    @Column(name = "tariff_charge", nullable = false)
    private Double tariffCharge;

    @Column(name = "fixed_charge", nullable = false)
    private Double fixedCharge;

    @Column(name = "tax_amount", nullable = false)
    private Double taxAmount;

    @Column(name = "penalty_amount", nullable = false)
    private Double penaltyAmount;

    @Column(name = "total_amount", nullable = false)
    private Double totalAmount;

    @Column(name = "outstanding_balance", nullable = false)
    private Double outstandingBalance;

    @Column(name = "bill_status", nullable = false)
    @Enumerated(EnumType.STRING)
    private BillStatus billStatus;

    @Column(name = "due_date", nullable = false)
    private LocalDate dueDate;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "approved_by")
    private User approvedBy;

    @Column(name = "approved_at")
    private LocalDateTime approvedAt;

    @Column(name = "generated_at")
    private LocalDateTime generatedAt;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    public enum BillStatus {
        PENDING, PARTIALLY_PAID, PAID, OVERDUE, APPROVED
    }
}
