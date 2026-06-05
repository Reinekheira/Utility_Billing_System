package com.utility.billing.controller;

import com.utility.billing.dto.CustomerRequest;
import com.utility.billing.entity.Customer;
import com.utility.billing.service.CustomerService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/customers")
@Tag(name = "Customer Management", description = "Customer CRUD operations")
public class CustomerController {

    private final CustomerService customerService;

    public CustomerController(CustomerService customerService) {
        this.customerService = customerService;
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Create customer", description = "Register a new customer (Admin only)")
    public ResponseEntity<Customer> createCustomer(@Valid @RequestBody CustomerRequest request) {
        return ResponseEntity.ok(customerService.createCustomer(request));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN', 'FINANCE', 'OPERATOR')")
    @Operation(summary = "Get all customers", description = "Retrieve all customers")
    public ResponseEntity<List<Customer>> getAllCustomers() {
        return ResponseEntity.ok(customerService.getAllCustomers());
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN', 'FINANCE', 'OPERATOR', 'CUSTOMER')")
    @Operation(summary = "Get customer by ID", description = "Retrieve a specific customer")
    public ResponseEntity<Customer> getCustomerById(@PathVariable Long id) {
        return ResponseEntity.ok(customerService.getCustomerById(id));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Update customer", description = "Update customer details (Admin only)")
    public ResponseEntity<Customer> updateCustomer(@PathVariable Long id,
                                                    @Valid @RequestBody CustomerRequest request) {
        return ResponseEntity.ok(customerService.updateCustomer(id, request));
    }

    @PutMapping("/{customerId}/link-user/{userId}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Link user to customer", description = "Associate a user account with a customer (Admin only)")
    public ResponseEntity<Customer> linkUserToCustomer(@PathVariable Long customerId,
                                                       @PathVariable Long userId) {
        return ResponseEntity.ok(customerService.linkUserToCustomer(customerId, userId));
    }
}
