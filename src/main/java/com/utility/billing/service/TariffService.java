package com.utility.billing.service;

import com.utility.billing.dto.TariffRequest;
import com.utility.billing.dto.TariffTierRequest;
import com.utility.billing.entity.Meter;
import com.utility.billing.entity.Tariff;
import com.utility.billing.entity.TariffTier;
import com.utility.billing.exception.BusinessRuleException;
import com.utility.billing.exception.ResourceNotFoundException;
import com.utility.billing.repository.TariffRepository;
import com.utility.billing.repository.TariffTierRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;

@Service
@Transactional
public class TariffService {

    private final TariffRepository tariffRepository;
    private final TariffTierRepository tariffTierRepository;

    public TariffService(TariffRepository tariffRepository, TariffTierRepository tariffTierRepository) {
        this.tariffRepository = tariffRepository;
        this.tariffTierRepository = tariffTierRepository;
    }

    public Tariff createTariff(TariffRequest request) {
        Meter.MeterType meterType = Meter.MeterType.valueOf(request.getMeterType().toUpperCase());

        // Get current max version for this meter type
        List<Tariff> existing = tariffRepository.findByMeterType(meterType);
        int maxVersion = existing.stream()
                .mapToInt(Tariff::getVersion)
                .max()
                .orElse(0);

        // Expire previous tariffs by setting effective_to
        existing.stream()
                .filter(t -> Boolean.TRUE.equals(t.getIsActive()) && t.getEffectiveTo() == null)
                .forEach(t -> {
                    t.setEffectiveTo(request.getEffectiveFrom().minusDays(1));
                    t.setIsActive(false);
                    tariffRepository.save(t);
                });

        Tariff tariff = Tariff.builder()
                .meterType(meterType)
                .tariffType(Tariff.TariffType.valueOf(request.getTariffType().toUpperCase()))
                .version(maxVersion + 1)
                .effectiveFrom(request.getEffectiveFrom())
                .isActive(true)
                .build();

        tariff = tariffRepository.save(tariff);

        // Create tiers
        if (request.getTiers() != null) {
            for (TariffTierRequest tierReq : request.getTiers()) {
                TariffTier tier = TariffTier.builder()
                        .tariff(tariff)
                        .minConsumption(tierReq.getMinConsumption() != null ? tierReq.getMinConsumption() : 0.0)
                        .maxConsumption(tierReq.getMaxConsumption())
                        .rate(tierReq.getRate())
                        .description(tierReq.getDescription())
                        .build();
                tariffTierRepository.save(tier);
            }
        }

        return tariff;
    }

    @Transactional(readOnly = true)
    public Tariff getTariffById(Long id) {
        return tariffRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Tariff not found with id: " + id));
    }

    @Transactional(readOnly = true)
    public List<Tariff> getAllTariffs() {
        return tariffRepository.findAll();
    }

    @Transactional(readOnly = true)
    public List<Tariff> getActiveTariffs() {
        return tariffRepository.findByIsActiveTrue();
    }

    @Transactional(readOnly = true)
    public Tariff getActiveTariffForMeterType(Meter.MeterType meterType) {
        return tariffRepository.findTopByMeterTypeAndIsActiveTrueAndEffectiveFromLessThanEqualOrderByVersionDesc(
                meterType, LocalDate.now())
                .orElseThrow(() -> new BusinessRuleException("No active tariff found for " + meterType));
    }

    @Transactional(readOnly = true)
    public List<TariffTier> getTariffTiers(Long tariffId) {
        return tariffTierRepository.findByTariffIdOrderByMinConsumptionAsc(tariffId);
    }
}
