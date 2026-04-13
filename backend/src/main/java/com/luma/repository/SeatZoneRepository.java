package com.luma.repository;

import com.luma.entity.Event;
import com.luma.entity.SeatZone;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface SeatZoneRepository extends JpaRepository<SeatZone, UUID> {

    List<SeatZone> findByEventOrderByDisplayOrderAsc(Event event);
}
