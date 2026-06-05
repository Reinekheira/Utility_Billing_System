package com.utility.billing.dto;

import jakarta.validation.constraints.NotNull;
import lombok.*;

import java.time.LocalDate;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MeterReadingRequest {

    @NotNull(message = "Meter ID is required")
    private Long meterId;

    @NotNull(message = "Previous reading is required")
    private Double previousReading;

    @NotNull(message = "Current reading is required")
    private Double currentReading;

    @NotNull(message = "Reading date is required")
    private LocalDate readingDate;
}
