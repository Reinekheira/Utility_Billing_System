package com.utility.billing.dto;

import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TariffTierRequest {

    private Double minConsumption;
    private Double maxConsumption;
    private Double rate;
    private String description;
}
