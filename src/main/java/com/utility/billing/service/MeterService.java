package com.utility.billing.service;

import com.utility.billing.dto.MeterRequest;
import com.utility.billing.entity.Customer;
import com.utility.billing.entity.Meter;
import com.utility.billing.exception.BusinessRuleException;
import com.utility.billing.exception.ResourceNotFoundException;
import com.utility.billing.repository.CustomerRepository;
import com.utility.billing.repository.MeterRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@Transactional
public class MeterService {

    private final MeterRepository meterRepository;
    private final CustomerRepository customerRepository;

    public MeterService(MeterRepository meterRepository, CustomerRepository customerRepository) {
        this.meterRepository = meterRepository;
        this.customerRepository = customerRepository;
    }

    public Meter createMeter(MeterRequest request) {
        if (meterRepository.existsByMeterNumber(request.getMeterNumber())) {
            throw new BusinessRuleException("Meter with this number already exists!");
        }

        Customer customer = customerRepository.findById(request.getCustomerId())
                .orElseThrow(() -> new ResourceNotFoundException("Customer not found with id: " + request.getCustomerId()));

        Meter meter = Meter.builder()
                .meterNumber(request.getMeterNumber())
                .meterType(Meter.MeterType.valueOf(request.getMeterType().toUpperCase()))
                .installationDate(request.getInstallationDate())
                .status(request.getStatus() != null
                        ? Meter.MeterStatus.valueOf(request.getStatus().toUpperCase())
                        : Meter.MeterStatus.ACTIVE)
                .customer(customer)
                .build();

        return meterRepository.save(meter);
    }

    @Transactional(readOnly = true)
    public Meter getMeterById(Long id) {
        return meterRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Meter not found with id: " + id));
    }

    @Transactional(readOnly = true)
    public List<Meter> getMetersByCustomer(Long customerId) {
        return meterRepository.findByCustomerId(customerId);
    }

    @Transactional(readOnly = true)
    public List<Meter> getAllMeters() {
        return meterRepository.findAll();
    }

    public Meter updateMeterStatus(Long id, String status) {
        Meter meter = getMeterById(id);
        meter.setStatus(Meter.MeterStatus.valueOf(status.toUpperCase()));
        return meterRepository.save(meter);
    }
}
