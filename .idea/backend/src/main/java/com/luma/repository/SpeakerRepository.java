package com.luma.repository;

import com.luma.entity.Speaker;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface SpeakerRepository extends JpaRepository<Speaker, Long> {
}
