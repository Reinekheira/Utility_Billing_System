package com.utility.billing.repository;

import com.utility.billing.entity.Customer;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface CustomerRepository extends JpaRepository<Customer, Long> {

    Optional<Customer> findByNationalId(String nationalId);

    Boolean existsByNationalId(String nationalId);

    Boolean existsByEmail(String email);
}
