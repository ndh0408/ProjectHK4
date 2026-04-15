package com.luma.repository;

import com.luma.entity.PollOption;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Repository
public interface PollOptionRepository extends JpaRepository<PollOption, UUID> {

    @Modifying
    @Transactional
    @Query("UPDATE PollOption o SET o.voteCount = o.voteCount + 1 WHERE o.id = :id")
    int incrementVoteCount(@Param("id") UUID id);
}
