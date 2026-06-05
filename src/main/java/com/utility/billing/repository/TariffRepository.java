package com.utility.billing.repository;

import com.utility.billing.entity.Tariff;
import com.utility.billing.entity.Meter;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface TariffRepository extends JpaRepository<Tariff, Long> {

    List<Tariff> findByMeterType(Meter.MeterType meterType);

    Optional<Tariff> findTopByMeterTypeAndIsActiveTrueAndEffectiveFromLessThanEqualOrderByVersionDesc(
        Meter.MeterType meterType, java.time.LocalDate date);

    List<Tariff> findByIsActiveTrue();
}
