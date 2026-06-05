package com.utility.billing.repository;

import com.utility.billing.entity.Payment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface PaymentRepository extends JpaRepository<Payment, Long> {

    List<Payment> findByBillId(Long billId);

    List<Payment> findByBillCustomerId(Long customerId);

    @Query("SELECT COALESCE(SUM(p.amountPaid), 0.0) FROM Payment p WHERE p.bill.id = :billId")
    Double sumAmountPaidByBillId(@Param("billId") Long billId);
}
