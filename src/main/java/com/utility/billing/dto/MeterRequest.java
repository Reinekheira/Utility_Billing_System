package com.utility.billing.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.*;

import java.time.LocalDate;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MeterRequest {

    @NotBlank(message = "Meter number is required")
    private String meterNumber;

    @NotBlank(message = "Meter type is required")
    private String meterType;

    @NotNull(message = "Installation date is required")
    private LocalDate installationDate;

    private String status;

    @NotNull(message = "Customer ID is required")
    private Long customerId;
}
