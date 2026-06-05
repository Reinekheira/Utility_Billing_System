package com.utility.billing.controller;

import com.utility.billing.dto.BillGenerateRequest;
import com.utility.billing.entity.Bill;
import com.utility.billing.service.BillService;
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
@RequestMapping("/api/bills")
@Tag(name = "Bill Management", description = "Bill generation, approval, and retrieval APIs")
public class BillController {

    private final BillService billService;

    public BillController(BillService billService) {
        this.billService = billService;
    }

    @PostMapping("/generate")
    @PreAuthorize("hasAnyRole('ADMIN', 'FINANCE')")
    @Operation(summary = "Generate bill", description = "Generate a bill from a meter reading (Admin/Finance)")
    public ResponseEntity<Bill> generateBill(
            @Valid @RequestBody BillGenerateRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(billService.generateBill(
                request.getMeterReadingId(), request.getDueDate(), userDetails.getUsername()));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN', 'FINANCE')")
    @Operation(summary = "Get all bills")
    public ResponseEntity<List<Bill>> getAllBills() {
        return ResponseEntity.ok(billService.getAllBills());
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN', 'FINANCE', 'CUSTOMER')")
    @Operation(summary = "Get bill by ID")
    public ResponseEntity<Bill> getBillById(@PathVariable Long id) {
        return ResponseEntity.ok(billService.getBillById(id));
    }

    @GetMapping("/customer/{customerId}")
    @PreAuthorize("hasAnyRole('ADMIN', 'FINANCE', 'CUSTOMER')")
    @Operation(summary = "Get bills by customer")
    public ResponseEntity<List<Bill>> getBillsByCustomer(@PathVariable Long customerId) {
        return ResponseEntity.ok(billService.getBillsByCustomer(customerId));
    }

    @GetMapping("/status/{status}")
    @PreAuthorize("hasAnyRole('ADMIN', 'FINANCE')")
    @Operation(summary = "Get bills by status")
    public ResponseEntity<List<Bill>> getBillsByStatus(@PathVariable Bill.BillStatus status) {
        return ResponseEntity.ok(billService.getBillsByStatus(status));
    }

    @PutMapping("/{id}/approve")
    @PreAuthorize("hasAnyRole('ADMIN', 'FINANCE')")
    @Operation(summary = "Approve bill", description = "Approve a pending bill (Admin/Finance)")
    public ResponseEntity<Bill> approveBill(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(billService.approveBill(id, userDetails.getUsername()));
    }
}
