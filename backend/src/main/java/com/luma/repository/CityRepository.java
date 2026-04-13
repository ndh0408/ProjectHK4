package com.luma.repository;

import com.luma.entity.City;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface CityRepository extends JpaRepository<City, Long> {

    Optional<City> findByName(String name);

    List<City> findByNameContainingIgnoreCase(String name);

    boolean existsByName(String name);

    Optional<City> findByNameAndCountry(String name, String country);

    List<City> findByContinent(String continent);

    List<City> findByActiveTrue();

    @Query("SELECT c FROM City c WHERE c.active = true AND " +
           "(SELECT COUNT(e) FROM Event e WHERE e.city = c AND e.status = 'PUBLISHED') > 0")
    List<City> findCitiesWithEvents();

    @Query("SELECT c.continent, COUNT(c) FROM City c WHERE c.active = true GROUP BY c.continent")
    List<Object[]> countCitiesByContinent();

    @Query("SELECT c FROM City c WHERE c.continent = :continent AND c.active = true AND " +
           "(SELECT COUNT(e) FROM Event e WHERE e.city = c AND e.status = 'PUBLISHED') > 0")
    List<City> findCitiesWithEventsByContinent(@Param("continent") String continent);
}
