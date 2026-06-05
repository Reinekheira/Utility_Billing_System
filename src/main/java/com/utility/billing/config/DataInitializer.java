package com.utility.billing.config;

import com.utility.billing.entity.Role;
import com.utility.billing.entity.User;
import com.utility.billing.repository.RoleRepository;
import com.utility.billing.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.util.Set;

@Component
@RequiredArgsConstructor
@Slf4j
public class DataInitializer implements CommandLineRunner {

    private final RoleRepository roleRepository;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Override
    public void run(String... args) {
        // Roles are already inserted by migration, but ensure they exist
        ensureRoleExists("ROLE_ADMIN");
        ensureRoleExists("ROLE_OPERATOR");
        ensureRoleExists("ROLE_FINANCE");
        ensureRoleExists("ROLE_CUSTOMER");

        // Create default admin user if not exists
        if (!userRepository.existsByEmail("admin@utilitybilling.rw")) {
            Role adminRole = roleRepository.findByName("ROLE_ADMIN")
                    .orElseThrow(() -> new RuntimeException("Admin role not found"));

            User admin = User.builder()
                    .fullNames("System Administrator")
                    .email("admin@utilitybilling.rw")
                    .phoneNumber("+250788000000")
                    .password(passwordEncoder.encode("Admin@123"))
                    .status(User.UserStatus.ACTIVE)
                    .roles(Set.of(adminRole))
                    .build();
            userRepository.save(admin);
            log.info("Default admin user created: admin@utilitybilling.rw / Admin@123");
        }

        // Create default operator
        if (!userRepository.existsByEmail("operator@utilitybilling.rw")) {
            Role operatorRole = roleRepository.findByName("ROLE_OPERATOR")
                    .orElseThrow(() -> new RuntimeException("Operator role not found"));

            User operator = User.builder()
                    .fullNames("Meter Operator")
                    .email("operator@utilitybilling.rw")
                    .phoneNumber("+250788000001")
                    .password(passwordEncoder.encode("Operator@123"))
                    .status(User.UserStatus.ACTIVE)
                    .roles(Set.of(operatorRole))
                    .build();
            userRepository.save(operator);
            log.info("Default operator user created: operator@utilitybilling.rw / Operator@123");
        }

        // Create default finance user
        if (!userRepository.existsByEmail("finance@utilitybilling.rw")) {
            Role financeRole = roleRepository.findByName("ROLE_FINANCE")
                    .orElseThrow(() -> new RuntimeException("Finance role not found"));

            User finance = User.builder()
                    .fullNames("Finance Officer")
                    .email("finance@utilitybilling.rw")
                    .phoneNumber("+250788000002")
                    .password(passwordEncoder.encode("Finance@123"))
                    .status(User.UserStatus.ACTIVE)
                    .roles(Set.of(financeRole))
                    .build();
            userRepository.save(finance);
            log.info("Default finance user created: finance@utilitybilling.rw / Finance@123");
        }
    }

    private void ensureRoleExists(String roleName) {
        if (roleRepository.findByName(roleName).isEmpty()) {
            roleRepository.save(new Role(roleName));
            log.info("Created role: {}", roleName);
        }
    }
}
