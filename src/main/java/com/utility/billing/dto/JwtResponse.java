package com.utility.billing.dto;

import lombok.*;

import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class JwtResponse {

    private String token;
    private String type = "Bearer";
    private Long id;
    private String email;
    private String fullNames;
    private List<String> roles;
}
