package com.utility.billing.service;

import com.utility.billing.entity.*;
import com.utility.billing.exception.BusinessRuleException;
import com.utility.billing.exception.ResourceNotFoundException;
import com.utility.billing.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

@Service
@Transactional
public class BillService {

    private final BillRepository billRepository;
    private final MeterReadingRepository meterReadingRepository;
    private final MeterRepository meterRepository;
    private final CustomerRepository customerRepository;
    private final TariffRepository tariffRepository;
    private final TariffTierRepository tariffTierRepository;
    private final FixedChargeRepository fixedChargeRepository;
    private final TaxRepository taxRepository;
    private final PenaltyRepository penaltyRepository;
    private final PaymentRepository paymentRepository;
    private final UserRepository userRepository;

    public BillService(BillRepository billRepository, MeterReadingRepository meterReadingRepository,
                       MeterRepository meterRepository, CustomerRepository customerRepository,
                       TariffRepository tariffRepository, TariffTierRepository tariffTierRepository,
                       FixedChargeRepository fixedChargeRepository, TaxRepository taxRepository,
                       PenaltyRepository penaltyRepository, PaymentRepository paymentRepository,
                       UserRepository userRepository) {
        this.billRepository = billRepository;
        this.meterReadingRepository = meterReadingRepository;
        this.meterRepository = meterRepository;
        this.customerRepository = customerRepository;
        this.tariffRepository = tariffRepository;
        this.tariffTierRepository = tariffTierRepository;
        this.fixedChargeRepository = fixedChargeRepository;
        this.taxRepository = taxRepository;
        this.penaltyRepository = penaltyRepository;
        this.paymentRepository = paymentRepository;
        this.userRepository = userRepository;
    }

    public Bill generateBill(Long meterReadingId, LocalDate dueDate, String approverEmail) {
        MeterReading reading = meterReadingRepository.findById(meterReadingId)
                .orElseThrow(() -> new ResourceNotFoundException("Meter reading not found with id: " + meterReadingId));

        Meter meter = reading.getMeter();
        Customer customer = meter.getCustomer();

        // Rule: Customer must be active
        if (customer.getStatus() != Customer.CustomerStatus.ACTIVE) {
            throw new BusinessRuleException("Inactive customers cannot receive bills!");
        }

        // Rule: Meter must be active
        if (meter.getStatus() != Meter.MeterStatus.ACTIVE) {
            throw new BusinessRuleException("Cannot generate bill for inactive meter!");
        }

        // Rule: Check if bill already exists for this reading
        if (billRepository.existsByMeterReadingId(meterReadingId)) {
            throw new BusinessRuleException("Bill already exists for this meter reading!");
        }

        // Calculate consumption
        double consumption = reading.getCurrentReading() - reading.getPreviousReading();

        // Get active tariff
        Tariff tariff = tariffRepository
                .findTopByMeterTypeAndIsActiveTrueAndEffectiveFromLessThanEqualOrderByVersionDesc(
                        meter.getMeterType(), LocalDate.now())
                .orElseThrow(() -> new BusinessRuleException("No active tariff for meter type: " + meter.getMeterType()));

        // Calculate tariff charge
        double tariffCharge = calculateTariffCharge(tariff, consumption);

        // Get fixed charges
        double fixedCharge = fixedChargeRepository.findByMeterTypeAndIsActiveTrue(meter.getMeterType())
                .stream().mapToDouble(FixedCharge::getAmount).sum();

        // Get tax
        double taxPct = taxRepository.findByIsActiveTrue()
                .stream().mapToDouble(Tax::getPercentage).sum();
        double taxAmount = (tariffCharge + fixedCharge) * (taxPct / 100);

        // Check for overdue bills and apply penalty
        double penaltyAmount = 0;
        List<Penalty> activePenalties = penaltyRepository.findByIsActiveTrue();
        if (!activePenalties.isEmpty() && hasOverdueBills(customer.getId())) {
            double penaltyPct = activePenalties.stream().mapToDouble(Penalty::getPercentage).sum();
            penaltyAmount = (tariffCharge + fixedCharge) * (penaltyPct / 100);
        }

        double totalAmount = tariffCharge + fixedCharge + taxAmount + penaltyAmount;

        User approver = userRepository.findByEmail(approverEmail)
                .orElseThrow(() -> new ResourceNotFoundException("Approver not found"));

        String billNumber = "BILL-" + meter.getMeterType() + "-" +
                reading.getReadingMonth() + "-" + reading.getReadingYear() + "-" + meter.getMeterNumber();

        Bill bill = Bill.builder()
                .billNumber(billNumber)
                .customer(customer)
                .meter(meter)
                .meterReading(reading)
                .billingMonth(reading.getReadingMonth())
                .billingYear(reading.getReadingYear())
                .consumption(consumption)
                .tariffCharge(tariffCharge)
                .fixedCharge(fixedCharge)
                .taxAmount(taxAmount)
                .penaltyAmount(penaltyAmount)
                .totalAmount(totalAmount)
                .outstandingBalance(totalAmount)
                .billStatus(Bill.BillStatus.PENDING)
                .dueDate(dueDate)
                .approvedBy(approver)
                .approvedAt(LocalDateTime.now())
                .build();

        return billRepository.save(bill);
    }

    private double calculateTariffCharge(Tariff tariff, double consumption) {
        List<TariffTier> tiers = tariffTierRepository.findByTariffIdOrderByMinConsumptionAsc(tariff.getId());

        if (tiers.isEmpty()) {
            throw new BusinessRuleException("No tiers configured for tariff id: " + tariff.getId());
        }

        if (tariff.getTariffType() == Tariff.TariffType.FLAT) {
            return consumption * tiers.get(0).getRate();
        }

        // Tiered calculation
        double charge = 0;
        double remaining = consumption;

        for (TariffTier tier : tiers) {
            if (remaining <= 0) break;

            double tierMin = tier.getMinConsumption();
            double tierMax = tier.getMaxConsumption() != null ? tier.getMaxConsumption() : consumption + tierMin;
            double tierWidth = tierMax - tierMin;

            if (consumption > tierMin) {
                double consumable = Math.min(remaining, tierWidth);
                charge += consumable * tier.getRate();
                remaining -= consumable;
            }
        }

        return charge;
    }

    private boolean hasOverdueBills(Long customerId) {
        return billRepository.findByCustomerIdAndBillStatus(customerId, Bill.BillStatus.PENDING)
                .stream().anyMatch(b -> b.getDueDate().isBefore(LocalDate.now()));
    }

    @Transactional(readOnly = true)
    public Bill getBillById(Long id) {
        return billRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Bill not found with id: " + id));
    }

    @Transactional(readOnly = true)
    public List<Bill> getBillsByCustomer(Long customerId) {
        return billRepository.findByCustomerIdOrderByBillingYearDescBillingMonthDesc(customerId);
    }

    @Transactional(readOnly = true)
    public List<Bill> getBillsByStatus(Bill.BillStatus status) {
        return billRepository.findByBillStatus(status);
    }

    @Transactional(readOnly = true)
    public List<Bill> getAllBills() {
        return billRepository.findAll();
    }

    public Bill approveBill(Long billId, String approverEmail) {
        Bill bill = getBillById(billId);

        if (bill.getBillStatus() != Bill.BillStatus.PENDING) {
            throw new BusinessRuleException("Only PENDING bills can be approved!");
        }

        User approver = userRepository.findByEmail(approverEmail)
                .orElseThrow(() -> new ResourceNotFoundException("Approver not found"));

        bill.setBillStatus(Bill.BillStatus.APPROVED);
        bill.setApprovedBy(approver);
        bill.setApprovedAt(LocalDateTime.now());

        return billRepository.save(bill);
    }
}
