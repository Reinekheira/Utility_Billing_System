package com.utility.billing.service;

import com.utility.billing.dto.PaymentRequest;
import com.utility.billing.entity.Bill;
import com.utility.billing.entity.Payment;
import com.utility.billing.entity.User;
import com.utility.billing.exception.BusinessRuleException;
import com.utility.billing.exception.ResourceNotFoundException;
import com.utility.billing.repository.BillRepository;
import com.utility.billing.repository.PaymentRepository;
import com.utility.billing.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Service
@Transactional
public class PaymentService {

    private final PaymentRepository paymentRepository;
    private final BillRepository billRepository;
    private final UserRepository userRepository;

    public PaymentService(PaymentRepository paymentRepository, BillRepository billRepository,
                          UserRepository userRepository) {
        this.paymentRepository = paymentRepository;
        this.billRepository = billRepository;
        this.userRepository = userRepository;
    }

    public Payment recordPayment(PaymentRequest request, String financeEmail) {
        Bill bill = billRepository.findById(request.getBillId())
                .orElseThrow(() -> new ResourceNotFoundException("Bill not found with id: " + request.getBillId()));

        if (bill.getBillStatus() == Bill.BillStatus.PAID) {
            throw new BusinessRuleException("Bill is already fully paid!");
        }

        if (request.getAmountPaid() <= 0) {
            throw new BusinessRuleException("Payment amount must be greater than zero!");
        }

        User financeUser = userRepository.findByEmail(financeEmail)
                .orElseThrow(() -> new ResourceNotFoundException("Finance user not found"));

        Payment payment = Payment.builder()
                .bill(bill)
                .amountPaid(request.getAmountPaid())
                .paymentMethod(request.getPaymentMethod())
                .paymentDate(LocalDateTime.now())
                .referenceNumber(request.getReferenceNumber())
                .processedBy(financeUser)
                .build();

        payment = paymentRepository.save(payment);

        // Recalculate balance
        Double totalPaid = paymentRepository.sumAmountPaidByBillId(bill.getId());
        if (totalPaid == null) totalPaid = 0.0;

        double outstandingBalance = bill.getTotalAmount() - totalPaid;

        if (outstandingBalance <= 0) {
            bill.setOutstandingBalance(0.0);
            bill.setBillStatus(Bill.BillStatus.PAID);
        } else {
            bill.setOutstandingBalance(outstandingBalance);
            bill.setBillStatus(Bill.BillStatus.PARTIALLY_PAID);
        }

        billRepository.save(bill);

        return payment;
    }

    @Transactional(readOnly = true)
    public Payment getPaymentById(Long id) {
        return paymentRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Payment not found with id: " + id));
    }

    @Transactional(readOnly = true)
    public List<Payment> getPaymentsByBill(Long billId) {
        return paymentRepository.findByBillId(billId);
    }

    @Transactional(readOnly = true)
    public List<Payment> getPaymentsByCustomer(Long customerId) {
        return paymentRepository.findByBillCustomerId(customerId);
    }

    @Transactional(readOnly = true)
    public List<Payment> getAllPayments() {
        return paymentRepository.findAll();
    }
}
