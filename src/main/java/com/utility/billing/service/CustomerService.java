package com.utility.billing.service;

import com.utility.billing.dto.CustomerRequest;
import com.utility.billing.entity.Customer;
import com.utility.billing.entity.User;
import com.utility.billing.exception.BusinessRuleException;
import com.utility.billing.exception.ResourceNotFoundException;
import com.utility.billing.repository.CustomerRepository;
import com.utility.billing.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@Transactional
public class CustomerService {

    private final CustomerRepository customerRepository;
    private final UserRepository userRepository;

    public CustomerService(CustomerRepository customerRepository, UserRepository userRepository) {
        this.customerRepository = customerRepository;
        this.userRepository = userRepository;
    }

    public Customer createCustomer(CustomerRequest request) {
        if (customerRepository.existsByNationalId(request.getNationalId())) {
            throw new BusinessRuleException("Customer with this National ID already exists!");
        }

        if (customerRepository.existsByEmail(request.getEmail())) {
            throw new BusinessRuleException("Customer with this email already exists!");
        }

        Customer customer = Customer.builder()
                .fullNames(request.getFullNames())
                .nationalId(request.getNationalId())
                .email(request.getEmail())
                .phoneNumber(request.getPhoneNumber())
                .address(request.getAddress())
                .status(request.getStatus() != null
                        ? Customer.CustomerStatus.valueOf(request.getStatus().toUpperCase())
                        : Customer.CustomerStatus.ACTIVE)
                .build();

        return customerRepository.save(customer);
    }

    @Transactional(readOnly = true)
    public Customer getCustomerById(Long id) {
        return customerRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Customer not found with id: " + id));
    }

    @Transactional(readOnly = true)
    public List<Customer> getAllCustomers() {
        return customerRepository.findAll();
    }

    public Customer updateCustomer(Long id, CustomerRequest request) {
        Customer customer = getCustomerById(id);
        customer.setFullNames(request.getFullNames());
        customer.setEmail(request.getEmail());
        customer.setPhoneNumber(request.getPhoneNumber());
        customer.setAddress(request.getAddress());
        if (request.getStatus() != null) {
            customer.setStatus(Customer.CustomerStatus.valueOf(request.getStatus().toUpperCase()));
        }
        return customerRepository.save(customer);
    }

    public Customer linkUserToCustomer(Long customerId, Long userId) {
        Customer customer = getCustomerById(customerId);
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found with id: " + userId));
        customer.setUser(user);
        return customerRepository.save(customer);
    }
}
