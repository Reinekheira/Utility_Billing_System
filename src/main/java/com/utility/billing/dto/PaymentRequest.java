package com.utility.billing.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PaymentRequest {

    @NotNull(message = "Bill ID is required")
    private Long billId;

    @NotNull(message = "Amount paid is required")
    private Double amountPaid;

    @NotBlank(message = "Payment method is required")
    private String paymentMethod;

    private String referenceNumber;
}
