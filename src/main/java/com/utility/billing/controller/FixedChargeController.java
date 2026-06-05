package com.utility.billing.controller;

import com.utility.billing.entity.FixedCharge;
import com.utility.billing.entity.Meter;
import com.utility.billing.repository.FixedChargeRepository;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/fixed-charges")
@Tag(name = "Fixed Charge Management", description = "Fixed service charges configuration (Admin only)")
public class FixedChargeController {

    private final FixedChargeRepository fixedChargeRepository;

    public FixedChargeController(FixedChargeRepository fixedChargeRepository) {
        this.fixedChargeRepository = fixedChargeRepository;
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Create fixed charge", description = "Add a new fixed service charge (Admin only)")
    public ResponseEntity<FixedCharge> createFixedCharge(@Valid @RequestBody FixedChargeRequest request) {
        FixedCharge charge = FixedCharge.builder()
                .meterType(Meter.MeterType.valueOf(request.getMeterType().toUpperCase()))
                .chargeName(request.getChargeName())
                .amount(request.getAmount())
                .version(request.getVersion() != null ? request.getVersion() : 1)
                .effectiveFrom(request.getEffectiveFrom())
                .effectiveTo(request.getEffectiveTo())
                .isActive(true)
                .build();
        return ResponseEntity.ok(fixedChargeRepository.save(charge));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN', 'FINANCE', 'OPERATOR')")
    @Operation(summary = "Get all fixed charges")
    public ResponseEntity<List<FixedCharge>> getAllFixedCharges() {
        return ResponseEntity.ok(fixedChargeRepository.findAll());
    }

    @GetMapping("/active/{meterType}")
    @PreAuthorize("hasAnyRole('ADMIN', 'FINANCE', 'OPERATOR')")
    @Operation(summary = "Get active charges by meter type")
    public ResponseEntity<List<FixedCharge>> getActiveCharges(@PathVariable String meterType) {
        return ResponseEntity.ok(fixedChargeRepository.findByMeterTypeAndIsActiveTrue(
                Meter.MeterType.valueOf(meterType.toUpperCase())));
    }

    @PutMapping("/{id}/deactivate")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Deactivate fixed charge")
    public ResponseEntity<FixedCharge> deactivateCharge(@PathVariable Long id) {
        FixedCharge charge = fixedChargeRepository.findById(id)
                .orElseThrow(() -> new com.utility.billing.exception.ResourceNotFoundException("Fixed charge not found"));
        charge.setIsActive(false);
        charge.setEffectiveTo(LocalDate.now());
        return ResponseEntity.ok(fixedChargeRepository.save(charge));
    }

    @lombok.Data
    @lombok.Builder
    @lombok.NoArgsConstructor
    @lombok.AllArgsConstructor
    public static class FixedChargeRequest {
        private String meterType;
        private String chargeName;
        private Double amount;
        private Integer version;
        private LocalDate effectiveFrom;
        private LocalDate effectiveTo;
    }
}
