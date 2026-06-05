package com.utility.billing.repository;

import com.utility.billing.entity.Bill;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface BillRepository extends JpaRepository<Bill, Long> {

    List<Bill> findByCustomerId(Long customerId);

    List<Bill> findByCustomerIdAndBillStatus(Long customerId, Bill.BillStatus status);

    Boolean existsByMeterReadingId(Long meterReadingId);

    List<Bill> findByBillStatus(Bill.BillStatus status);

    List<Bill> findByCustomerIdOrderByBillingYearDescBillingMonthDesc(Long customerId);
}
