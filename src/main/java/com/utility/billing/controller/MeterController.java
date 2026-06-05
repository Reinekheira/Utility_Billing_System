package com.utility.billing.controller;

import com.utility.billing.dto.MeterRequest;
import com.utility.billing.entity.Meter;
import com.utility.billing.service.MeterService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/meters")
@Tag(name = "Meter Management", description = "Meter CRUD operations")
public class MeterController {

    private final MeterService meterService;

    public MeterController(MeterService meterService) {
        this.meterService = meterService;
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Create meter", description = "Register a new meter (Admin only)")
    public ResponseEntity<Meter> createMeter(@Valid @RequestBody MeterRequest request) {
        return ResponseEntity.ok(meterService.createMeter(request));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN', 'OPERATOR', 'FINANCE')")
    @Operation(summary = "Get all meters", description = "Retrieve all meters")
    public ResponseEntity<List<Meter>> getAllMeters() {
        return ResponseEntity.ok(meterService.getAllMeters());
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN', 'OPERATOR', 'FINANCE', 'CUSTOMER')")
    @Operation(summary = "Get meter by ID", description = "Retrieve a specific meter")
    public ResponseEntity<Meter> getMeterById(@PathVariable Long id) {
        return ResponseEntity.ok(meterService.getMeterById(id));
    }

    @GetMapping("/customer/{customerId}")
    @PreAuthorize("hasAnyRole('ADMIN', 'OPERATOR', 'FINANCE', 'CUSTOMER')")
    @Operation(summary = "Get meters by customer", description = "Retrieve all meters for a customer")
    public ResponseEntity<List<Meter>> getMetersByCustomer(@PathVariable Long customerId) {
        return ResponseEntity.ok(meterService.getMetersByCustomer(customerId));
    }

    @PutMapping("/{id}/status")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Update meter status", description = "Activate or deactivate a meter (Admin only)")
    public ResponseEntity<Meter> updateMeterStatus(@PathVariable Long id, @RequestParam String status) {
        return ResponseEntity.ok(meterService.updateMeterStatus(id, status));
    }
}
