package com.utility.billing.repository;

import com.utility.billing.entity.MeterReading;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface MeterReadingRepository extends JpaRepository<MeterReading, Long> {

    Optional<MeterReading> findByMeterIdAndReadingMonthAndReadingYear(Long meterId, Integer month, Integer year);

    List<MeterReading> findByMeterId(Long meterId);

    List<MeterReading> findByMeterCustomerId(Long customerId);

    Optional<MeterReading> findTopByMeterIdOrderByReadingYearDescReadingMonthDesc(Long meterId);
}
