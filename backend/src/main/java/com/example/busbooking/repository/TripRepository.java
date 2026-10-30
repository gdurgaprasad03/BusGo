package com.example.busbooking.repository;

import com.example.busbooking.entity.Trip;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface TripRepository extends JpaRepository<Trip, Long> {

    /** "join fetch" loads bus and operator in the same query (avoids one extra query per row). */
    @Query("""
            select t from Trip t
              join fetch t.bus b
              join fetch b.operator
            where lower(t.source) = lower(:source)
              and lower(t.destination) = lower(:destination)
              and t.departureTime >= :from
              and t.departureTime < :to
            order by t.departureTime
            """)
    List<Trip> search(@Param("source") String source,
                      @Param("destination") String destination,
                      @Param("from") LocalDateTime from,
                      @Param("to") LocalDateTime to);

    @Query("""
            select t from Trip t
              join fetch t.bus b
              join fetch b.operator
            where t.id = :id
            """)
    Optional<Trip> findDetailedById(@Param("id") Long id);

    boolean existsByBusIdAndDepartureTime(Long busId, LocalDateTime departureTime);

    /** Departure times this bus already has from {@code from} on (lets the seeder skip existing trips in one query). */
    @Query("select t.departureTime from Trip t where t.bus.id = :busId and t.departureTime >= :from")
    List<LocalDateTime> departureTimesFrom(@Param("busId") Long busId, @Param("from") LocalDateTime from);

    /** Places that currently have trips (used to flag which places in the catalog have demo service). */
    @Query("select distinct t.source from Trip t")
    List<String> distinctSources();

    @Query("select distinct t.destination from Trip t")
    List<String> distinctDestinations();
}
