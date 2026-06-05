package com.utility.billing.controller;

import com.utility.billing.dto.TariffRequest;
import com.utility.billing.entity.Meter;
import com.utility.billing.entity.Tariff;
import com.utility.billing.entity.TariffTier;
import com.utility.billing.service.TariffService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/tariffs")
@Tag(name = "Tariff Management", description = "Tariff, tier configuration APIs (Admin only)")
public class TariffController {

    private final TariffService tariffService;

    public TariffController(TariffService tariffService) {
        this.tariffService = tariffService;
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Create tariff", description = "Create a new versioned tariff with tiers (Admin only)")
    public ResponseEntity<Tariff> createTariff(@Valid @RequestBody TariffRequest request) {
        return ResponseEntity.ok(tariffService.createTariff(request));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN', 'FINANCE', 'OPERATOR')")
    @Operation(summary = "Get all tariffs")
    public ResponseEntity<List<Tariff>> getAllTariffs() {
        return ResponseEntity.ok(tariffService.getAllTariffs());
    }

    @GetMapping("/active")
    @PreAuthorize("hasAnyRole('ADMIN', 'FINANCE', 'OPERATOR')")
    @Operation(summary = "Get active tariffs")
    public ResponseEntity<List<Tariff>> getActiveTariffs() {
        return ResponseEntity.ok(tariffService.getActiveTariffs());
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN', 'FINANCE', 'OPERATOR')")
    @Operation(summary = "Get tariff by ID")
    public ResponseEntity<Tariff> getTariffById(@PathVariable Long id) {
        return ResponseEntity.ok(tariffService.getTariffById(id));
    }

    @GetMapping("/{id}/tiers")
    @PreAuthorize("hasAnyRole('ADMIN', 'FINANCE', 'OPERATOR')")
    @Operation(summary = "Get tariff tiers", description = "Get all tiers for a specific tariff")
    public ResponseEntity<List<TariffTier>> getTariffTiers(@PathVariable Long id) {
        return ResponseEntity.ok(tariffService.getTariffTiers(id));
    }
}
