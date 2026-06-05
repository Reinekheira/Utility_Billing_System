package com.utility.billing.repository;

import com.utility.billing.entity.FixedCharge;
import com.utility.billing.entity.Meter;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface FixedChargeRepository extends JpaRepository<FixedCharge, Long> {

    List<FixedCharge> findByMeterTypeAndIsActiveTrue(Meter.MeterType meterType);
}
