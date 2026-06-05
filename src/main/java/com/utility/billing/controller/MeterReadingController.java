package com.utility.billing.controller;

import com.utility.billing.dto.MeterReadingRequest;
import com.utility.billing.entity.MeterReading;
import com.utility.billing.repository.MeterReadingRepository;
import com.utility.billing.service.MeterReadingService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/meter-readings")
@Tag(name = "Meter Reading Management", description = "Meter reading capture and retrieval APIs")
public class MeterReadingController {

    private final MeterReadingService meterReadingService;
    private final MeterReadingRepository meterReadingRepository;

    public MeterReadingController(MeterReadingService meterReadingService,
                                  MeterReadingRepository meterReadingRepository) {
        this.meterReadingService = meterReadingService;
        this.meterReadingRepository = meterReadingRepository;
    }

    @PostMapping
    @PreAuthorize("hasRole('OPERATOR')")
    @Operation(summary = "Capture meter reading", description = "Record a new meter reading (Operator only)")
    public ResponseEntity<MeterReading> captureReading(
            @Valid @RequestBody MeterReadingRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(meterReadingService.captureReading(request, userDetails.getUsername()));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN', 'OPERATOR', 'FINANCE')")
    @Operation(summary = "Get all meter readings")
    public ResponseEntity<List<MeterReading>> getAllReadings() {
        return ResponseEntity.ok(meterReadingRepository.findAll());
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN', 'OPERATOR', 'FINANCE')")
    @Operation(summary = "Get meter reading by ID")
    public ResponseEntity<MeterReading> getReadingById(@PathVariable Long id) {
        return ResponseEntity.ok(meterReadingService.getReadingById(id));
    }

    @GetMapping("/meter/{meterId}")
    @PreAuthorize("hasAnyRole('ADMIN', 'OPERATOR', 'FINANCE', 'CUSTOMER')")
    @Operation(summary = "Get readings by meter")
    public ResponseEntity<List<MeterReading>> getReadingsByMeter(@PathVariable Long meterId) {
        return ResponseEntity.ok(meterReadingService.getReadingsByMeter(meterId));
    }

    @GetMapping("/customer/{customerId}")
    @PreAuthorize("hasAnyRole('ADMIN', 'OPERATOR', 'FINANCE', 'CUSTOMER')")
    @Operation(summary = "Get readings by customer")
    public ResponseEntity<List<MeterReading>> getReadingsByCustomer(@PathVariable Long customerId) {
        return ResponseEntity.ok(meterReadingService.getReadingsByCustomer(customerId));
    }
}
