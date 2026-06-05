package com.utility.billing.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.*;

import java.time.LocalDate;
import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TariffRequest {

    @NotBlank(message = "Meter type is required")
    private String meterType;

    @NotBlank(message = "Tariff type is required")
    private String tariffType;

    @NotNull(message = "Effective from date is required")
    private LocalDate effectiveFrom;

    private List<TariffTierRequest> tiers;
}
