package com.utility.billing.controller;

import com.utility.billing.entity.Tax;
import com.utility.billing.repository.TaxRepository;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/taxes")
@Tag(name = "Tax Management", description = "Tax configuration APIs (Admin only)")
public class TaxController {

    private final TaxRepository taxRepository;

    public TaxController(TaxRepository taxRepository) {
        this.taxRepository = taxRepository;
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Create tax", description = "Add a new tax configuration (Admin only)")
    public ResponseEntity<Tax> createTax(@RequestBody TaxRequest request) {
        Tax tax = Tax.builder()
                .taxName(request.getTaxName())
                .taxType(request.getTaxType())
                .percentage(request.getPercentage())
                .isActive(true)
                .build();
        return ResponseEntity.ok(taxRepository.save(tax));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN', 'FINANCE', 'OPERATOR')")
    @Operation(summary = "Get all taxes")
    public ResponseEntity<List<Tax>> getAllTaxes() {
        return ResponseEntity.ok(taxRepository.findAll());
    }

    @GetMapping("/active")
    @PreAuthorize("hasAnyRole('ADMIN', 'FINANCE', 'OPERATOR')")
    @Operation(summary = "Get active taxes")
    public ResponseEntity<List<Tax>> getActiveTaxes() {
        return ResponseEntity.ok(taxRepository.findByIsActiveTrue());
    }

    @PutMapping("/{id}/deactivate")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Deactivate tax")
    public ResponseEntity<Tax> deactivateTax(@PathVariable Long id) {
        Tax tax = taxRepository.findById(id)
                .orElseThrow(() -> new com.utility.billing.exception.ResourceNotFoundException("Tax not found"));
        tax.setIsActive(false);
        return ResponseEntity.ok(taxRepository.save(tax));
    }

    @lombok.Data
    @lombok.Builder
    @lombok.NoArgsConstructor
    @lombok.AllArgsConstructor
    public static class TaxRequest {
        private String taxName;
        private String taxType;
        private Double percentage;
    }
}
