package com.utility.billing.service;

import com.utility.billing.dto.MeterReadingRequest;
import com.utility.billing.entity.Meter;
import com.utility.billing.entity.MeterReading;
import com.utility.billing.entity.User;
import com.utility.billing.exception.BusinessRuleException;
import com.utility.billing.exception.ResourceNotFoundException;
import com.utility.billing.repository.MeterReadingRepository;
import com.utility.billing.repository.MeterRepository;
import com.utility.billing.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;

@Service
@Transactional
public class MeterReadingService {

    private final MeterReadingRepository meterReadingRepository;
    private final MeterRepository meterRepository;
    private final UserRepository userRepository;

    public MeterReadingService(MeterReadingRepository meterReadingRepository,
                               MeterRepository meterRepository,
                               UserRepository userRepository) {
        this.meterReadingRepository = meterReadingRepository;
        this.meterRepository = meterRepository;
        this.userRepository = userRepository;
    }

    public MeterReading captureReading(MeterReadingRequest request, String operatorEmail) {
        Meter meter = meterRepository.findById(request.getMeterId())
                .orElseThrow(() -> new ResourceNotFoundException("Meter not found with id: " + request.getMeterId()));

        User operator = userRepository.findByEmail(operatorEmail)
                .orElseThrow(() -> new ResourceNotFoundException("Operator not found"));

        // Rule: Meter must be active
        if (meter.getStatus() != Meter.MeterStatus.ACTIVE) {
            throw new BusinessRuleException("Cannot capture reading for inactive meter!");
        }

        // Rule: Current reading must be greater than previous reading
        if (request.getCurrentReading() <= request.getPreviousReading()) {
            throw new BusinessRuleException("Current reading must be greater than previous reading!");
        }

        int month = request.getReadingDate().getMonthValue();
        int year = request.getReadingDate().getYear();

        // Rule: Only one reading per meter per Month/Year
        if (meterReadingRepository.findByMeterIdAndReadingMonthAndReadingYear(meter.getId(), month, year).isPresent()) {
            throw new BusinessRuleException("A reading already exists for this meter in " + month + "/" + year);
        }

        MeterReading reading = MeterReading.builder()
                .meter(meter)
                .previousReading(request.getPreviousReading())
                .currentReading(request.getCurrentReading())
                .readingDate(request.getReadingDate())
                .readingMonth(month)
                .readingYear(year)
                .capturedBy(operator)
                .build();

        return meterReadingRepository.save(reading);
    }

    @Transactional(readOnly = true)
    public MeterReading getReadingById(Long id) {
        return meterReadingRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Meter reading not found with id: " + id));
    }

    @Transactional(readOnly = true)
    public List<MeterReading> getReadingsByMeter(Long meterId) {
        return meterReadingRepository.findByMeterId(meterId);
    }

    @Transactional(readOnly = true)
    public List<MeterReading> getReadingsByCustomer(Long customerId) {
        return meterReadingRepository.findByMeterCustomerId(customerId);
    }

    @Transactional(readOnly = true)
    public MeterReading getLatestReading(Long meterId) {
        return meterReadingRepository.findTopByMeterIdOrderByReadingYearDescReadingMonthDesc(meterId)
                .orElseThrow(() -> new ResourceNotFoundException("No readings found for meter id: " + meterId));
    }
}
