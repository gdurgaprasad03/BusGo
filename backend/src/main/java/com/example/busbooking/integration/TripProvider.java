package com.example.busbooking.integration;

import com.example.busbooking.dto.TripResponse;

import java.util.List;

/**
 * A source of bus trips. Today there is one: the demo provider (sample data stored in our own database).
 *
 * To add a REAL provider you must have an official, authorised API agreement with that company. Then:
 * <ol>
 *   <li>Write a class that implements this interface and is a Spring {@code @Component}, enabled by a property.</li>
 *   <li>Read its URL and credentials from environment variables (never from source code) and log without secrets.</li>
 *   <li>Map its response to {@link TripResponse} with {@code dataSource = "LIVE"} and its own provider id.</li>
 *   <li>Set {@code bookable} to false unless you also implement booking and cancellation against that provider.</li>
 * </ol>
 * {@link TripSearchAggregator} then calls every provider, tolerates failures and merges the results.
 */
public interface TripProvider {

    /** Short stable id such as "demo". It is also written into every result. */
    String id();

    /** Searches this provider. Throwing an exception only affects this provider, never the whole search. */
    List<TripResponse> search(TripSearchCriteria criteria);
}
