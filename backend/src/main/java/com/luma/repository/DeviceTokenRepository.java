package com.luma.repository;

import com.luma.entity.DeviceToken;
import com.luma.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface DeviceTokenRepository extends JpaRepository<DeviceToken, UUID> {

    Optional<DeviceToken> findByToken(String token);

    List<DeviceToken> findByUser(User user);

    List<DeviceToken> findByUserId(UUID userId);

    @Modifying
    @Transactional
    @Query("DELETE FROM DeviceToken d WHERE d.token = :token")
    void deleteByToken(@Param("token") String token);

    @Modifying
    @Transactional
    @Query("DELETE FROM DeviceToken d WHERE d.user.id = :userId AND d.token = :token")
    void deleteByUserIdAndToken(@Param("userId") UUID userId, @Param("token") String token);

    @Modifying
    @Transactional
    @Query("DELETE FROM DeviceToken d WHERE d.token IN :tokens")
    void deleteByTokenIn(@Param("tokens") List<String> tokens);
}
