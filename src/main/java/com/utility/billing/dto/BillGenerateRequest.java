package com.utility.billing.dto;

import jakarta.validation.constraints.NotNull;
import lombok.*;

import java.time.LocalDate;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class BillGenerateRequest {

    @NotNull(message = "Meter reading ID is required")
    private Long meterReadingId;

    @NotNull(message = "Due date is required")
    private LocalDate dueDate;
}
