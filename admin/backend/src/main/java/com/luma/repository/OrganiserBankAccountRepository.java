package com.luma.repository;

import com.luma.entity.OrganiserBankAccount;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface OrganiserBankAccountRepository extends JpaRepository<OrganiserBankAccount, UUID> {

    Optional<OrganiserBankAccount> findByOrganiserId(UUID organiserId);

    Optional<OrganiserBankAccount> findByStripeAccountId(String stripeAccountId);

    boolean existsByOrganiserId(UUID organiserId);

    boolean existsByOrganiserIdAndPayoutsEnabledTrue(UUID organiserId);
}
