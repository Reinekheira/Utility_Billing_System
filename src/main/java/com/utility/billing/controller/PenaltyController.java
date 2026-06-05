package com.utility.billing.controller;

import com.utility.billing.entity.Penalty;
import com.utility.billing.repository.PenaltyRepository;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/penalties")
@Tag(name = "Penalty Management", description = "Late payment penalty configuration APIs (Admin only)")
public class PenaltyController {

    private final PenaltyRepository penaltyRepository;

    public PenaltyController(PenaltyRepository penaltyRepository) {
        this.penaltyRepository = penaltyRepository;
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Create penalty", description = "Add a new late payment penalty (Admin only)")
    public ResponseEntity<Penalty> createPenalty(@RequestBody PenaltyRequest request) {
        Penalty penalty = Penalty.builder()
                .penaltyName(request.getPenaltyName())
                .penaltyType(request.getPenaltyType())
                .percentage(request.getPercentage())
                .gracePeriodDays(request.getGracePeriodDays() != null ? request.getGracePeriodDays() : 30)
                .isActive(true)
                .build();
        return ResponseEntity.ok(penaltyRepository.save(penalty));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN', 'FINANCE', 'OPERATOR')")
    @Operation(summary = "Get all penalties")
    public ResponseEntity<List<Penalty>> getAllPenalties() {
        return ResponseEntity.ok(penaltyRepository.findAll());
    }

    @GetMapping("/active")
    @PreAuthorize("hasAnyRole('ADMIN', 'FINANCE', 'OPERATOR')")
    @Operation(summary = "Get active penalties")
    public ResponseEntity<List<Penalty>> getActivePenalties() {
        return ResponseEntity.ok(penaltyRepository.findByIsActiveTrue());
    }

    @PutMapping("/{id}/deactivate")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Deactivate penalty")
    public ResponseEntity<Penalty> deactivatePenalty(@PathVariable Long id) {
        Penalty penalty = penaltyRepository.findById(id)
                .orElseThrow(() -> new com.utility.billing.exception.ResourceNotFoundException("Penalty not found"));
        penalty.setIsActive(false);
        return ResponseEntity.ok(penaltyRepository.save(penalty));
    }

    @lombok.Data
    @lombok.Builder
    @lombok.NoArgsConstructor
    @lombok.AllArgsConstructor
    public static class PenaltyRequest {
        private String penaltyName;
        private String penaltyType;
        private Double percentage;
        private Integer gracePeriodDays;
    }
}
