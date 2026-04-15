package com.luma.repository;

import com.luma.entity.Coupon;
import com.luma.entity.CouponUsage;
import com.luma.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface CouponUsageRepository extends JpaRepository<CouponUsage, UUID> {

    long countByCouponAndUser(Coupon coupon, User user);

    boolean existsByCouponAndUser(Coupon coupon, User user);

    java.util.Optional<CouponUsage> findByRegistrationId(UUID registrationId);
}
