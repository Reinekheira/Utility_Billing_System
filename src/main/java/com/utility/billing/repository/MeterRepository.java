package com.utility.billing.repository;

import com.utility.billing.entity.Meter;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface MeterRepository extends JpaRepository<Meter, Long> {

    Optional<Meter> findByMeterNumber(String meterNumber);

    Boolean existsByMeterNumber(String meterNumber);

    List<Meter> findByCustomerId(Long customerId);

    List<Meter> findByCustomerIdAndMeterType(Long customerId, Meter.MeterType meterType);
}
