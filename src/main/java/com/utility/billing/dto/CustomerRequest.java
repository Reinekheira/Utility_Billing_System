package com.utility.billing.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CustomerRequest {

    @NotBlank(message = "Full names are required")
    private String fullNames;

    @NotBlank(message = "National ID is required")
    @Pattern(regexp = "^\\d{16}$", message = "National ID must be exactly 16 digits")
    private String nationalId;

    @NotBlank(message = "Email is required")
    @Email(message = "Invalid email format")
    private String email;

    @NotBlank(message = "Phone number is required")
    @Pattern(regexp = "^(\\+250|0)?7\\d{8}$", message = "Phone number must be a valid Rwandan number (e.g. +25078xxxxxxx or 078xxxxxxx)")
    private String phoneNumber;

    @NotBlank(message = "Address is required")
    private String address;

    private String status;
}
