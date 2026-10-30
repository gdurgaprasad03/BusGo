package com.example.busbooking.repository;

import com.example.busbooking.entity.SeatStatus;
import com.example.busbooking.entity.TripSeat;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;

public interface TripSeatRepository extends JpaRepository<TripSeat, Long> {

    List<TripSeat> findByTripIdOrderByDeckAscSeatRowAscSeatColAsc(Long tripId);

    long countByTripIdAndStatus(Long tripId, SeatStatus status);

    /** Available seats for many trips in ONE query (never hardcoded; always from the database). */
    @Query("""
            select new com.example.busbooking.repository.SeatCount(s.trip.id, count(s))
            from TripSeat s
            where s.trip.id in :tripIds
              and s.status = com.example.busbooking.entity.SeatStatus.AVAILABLE
            group by s.trip.id
            """)
    List<SeatCount> countAvailableByTripIds(@Param("tripIds") Collection<Long> tripIds);

    /**
     * SELECT ... FOR UPDATE on the requested seats. A second booking request for the same seats
     * waits here until the first transaction commits, then sees the seats as BOOKED.
     * "order by id" gives every transaction the same lock order, which avoids deadlocks.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
            select s from TripSeat s
            where s.trip.id = :tripId and s.seatNumber in :seatNumbers
            order by s.id
            """)
    List<TripSeat> lockSeats(@Param("tripId") Long tripId,
                             @Param("seatNumbers") Collection<String> seatNumbers);
}
