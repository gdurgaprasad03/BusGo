package com.example.busbooking.service;

import com.example.busbooking.catalog.DemoRouteCatalog;
import com.example.busbooking.entity.Bus;
import com.example.busbooking.entity.BusType;
import com.example.busbooking.entity.Deck;
import com.example.busbooking.entity.Operator;
import com.example.busbooking.entity.Trip;
import com.example.busbooking.repository.BusRepository;
import com.example.busbooking.repository.OperatorRepository;
import com.example.busbooking.repository.TripRepository;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.Set;
import java.util.stream.IntStream;

/**
 * Generates DEMO operators, buses, trips and seat inventory. All names, ratings, fares and schedules are
 * invented sample data, not live data. Trips are generated for the next DAYS_AHEAD days relative to
 * today, so searches keep working as time passes (the app tops up missing days on every startup).
 */
@Service
public class DemoDataService {

    /** Number of days (from today) that demo trips are generated for. Tests use a smaller value to run faster. */
    @org.springframework.beans.factory.annotation.Value("${app.demo.days-ahead:14}")
    private int daysAhead = 14;

    private record OperatorSpec(String name, String rating) {}

    /** One recurring daily departure. bookedPercent = share of seats pre-sold to "other customers". */
    private record Template(String source, String destination, int operator, BusType type,
                            String departure, int durationMinutes, int fare, int bookedPercent) {}

    private record SeatSpec(String number, Deck deck, int row, int col) {}

    private static final List<OperatorSpec> OPERATORS = List.of(
            new OperatorSpec("SkyLine Travels", "4.4"),
            new OperatorSpec("GreenLine Express", "4.1"),
            new OperatorSpec("BlueWave Tours", "4.6"),
            new OperatorSpec("Sunrise Travels", "3.9"),
            new OperatorSpec("MetroLink Coaches", "4.2"),
            new OperatorSpec("Royal Cruiser", "4.5"));

    private static final Map<String, String> BOARDING = Map.ofEntries(
            Map.entry("Kurnool", "Kurnool Bus Stand"), Map.entry("Hyderabad", "Ameerpet X Roads"),
            Map.entry("Bengaluru", "Majestic Bus Station"), Map.entry("Chennai", "Koyambedu CMBT"),
            Map.entry("Vijayawada", "Pandit Nehru Bus Station"), Map.entry("Delhi", "Kashmere Gate ISBT"),
            Map.entry("Jaipur", "Sindhi Camp Bus Stand"), Map.entry("Mumbai", "Dadar East"),
            Map.entry("Pune", "Swargate"), Map.entry("Visakhapatnam", "RTC Complex"),
            Map.entry("Tirupati", "Tirupati Central Bus Stand"), Map.entry("Mysuru", "Mysuru City Bus Stand"),
            Map.entry("Coimbatore", "Gandhipuram Bus Stand"), Map.entry("Madurai", "Mattuthavani Bus Stand"),
            Map.entry("Panaji", "Panaji Kadamba Bus Stand"), Map.entry("Ahmedabad", "Geeta Mandir"),
            Map.entry("Chandigarh", "ISBT Sector 17"), Map.entry("Agra", "Idgah Bus Stand"),
            Map.entry("Warangal", "Hanamkonda Bus Stand"), Map.entry("Karimnagar", "Karimnagar Bus Stand"),
            Map.entry("Nizamabad", "Nizamabad Bus Stand"), Map.entry("Guntur", "Guntur Bus Station"),
            Map.entry("Nellore", "Nellore Bus Stand"), Map.entry("Rajahmundry", "Rajahmundry Bus Stand"),
            Map.entry("Anantapur", "Anantapur Bus Stand"), Map.entry("Kadapa", "Kadapa Bus Stand"),
            Map.entry("Mahbubnagar", "Mahbubnagar Bus Stand"));

    private static final Map<String, String> DROPPING = Map.ofEntries(
            Map.entry("Kurnool", "Kurnool Bus Stand"), Map.entry("Hyderabad", "MGBS"),
            Map.entry("Bengaluru", "Madiwala"), Map.entry("Chennai", "Guindy"),
            Map.entry("Vijayawada", "Benz Circle"), Map.entry("Delhi", "Anand Vihar ISBT"),
            Map.entry("Jaipur", "Narayan Singh Circle"), Map.entry("Mumbai", "Borivali"),
            Map.entry("Pune", "Shivajinagar"), Map.entry("Visakhapatnam", "Maddilapalem"),
            Map.entry("Tirupati", "Alipiri Bus Point"), Map.entry("Mysuru", "Mysuru Railway Station"),
            Map.entry("Coimbatore", "Ukkadam Bus Stand"), Map.entry("Madurai", "Periyar Bus Stand"),
            Map.entry("Panaji", "Mapusa Bus Stand"), Map.entry("Ahmedabad", "Paldi"),
            Map.entry("Chandigarh", "ISBT Sector 43"), Map.entry("Agra", "ISBT Agra"),
            Map.entry("Warangal", "Warangal Bus Station"), Map.entry("Karimnagar", "Karimnagar Bus Stand"),
            Map.entry("Nizamabad", "Nizamabad Bus Stand"), Map.entry("Guntur", "Guntur Bus Station"),
            Map.entry("Nellore", "Nellore Bus Stand"), Map.entry("Rajahmundry", "Rajahmundry Bus Stand"),
            Map.entry("Anantapur", "Anantapur Bus Stand"), Map.entry("Kadapa", "Kadapa Bus Stand"),
            Map.entry("Mahbubnagar", "Mahbubnagar Bus Stand"));

    // Mix of: plenty of seats (low %), few seats left (90-93%), and one fully sold out (100%) per major route.
    private static final List<Template> CORE_TEMPLATES = List.of(
            new Template("Kurnool", "Hyderabad", 0, BusType.AC_SEATER, "06:30", 270, 550, 20),
            new Template("Kurnool", "Hyderabad", 1, BusType.NON_AC_SEATER, "09:00", 270, 420, 45),
            new Template("Kurnool", "Hyderabad", 2, BusType.AC_SLEEPER, "21:30", 270, 899, 30),
            new Template("Kurnool", "Hyderabad", 5, BusType.NON_AC_SLEEPER, "23:00", 270, 699, 93),
            new Template("Kurnool", "Hyderabad", 3, BusType.AC_SEATER, "23:45", 270, 650, 100), // sold out
            new Template("Hyderabad", "Kurnool", 0, BusType.AC_SEATER, "07:00", 270, 550, 10),
            new Template("Hyderabad", "Kurnool", 1, BusType.NON_AC_SEATER, "18:30", 270, 430, 70),
            new Template("Hyderabad", "Kurnool", 2, BusType.AC_SLEEPER, "22:00", 270, 899, 55),
            new Template("Hyderabad", "Bengaluru", 0, BusType.AC_SEATER, "21:00", 540, 1100, 50),
            new Template("Hyderabad", "Bengaluru", 4, BusType.NON_AC_SEATER, "19:30", 540, 820, 25),
            new Template("Hyderabad", "Bengaluru", 5, BusType.AC_SLEEPER, "20:00", 540, 1350, 35),
            new Template("Hyderabad", "Bengaluru", 3, BusType.NON_AC_SLEEPER, "22:00", 540, 950, 90),
            new Template("Bengaluru", "Hyderabad", 1, BusType.NON_AC_SEATER, "20:00", 540, 800, 60),
            new Template("Bengaluru", "Hyderabad", 2, BusType.AC_SLEEPER, "21:00", 540, 1400, 40),
            new Template("Bengaluru", "Hyderabad", 5, BusType.AC_SEATER, "22:30", 540, 1150, 15),
            new Template("Bengaluru", "Chennai", 0, BusType.AC_SEATER, "07:00", 390, 690, 20),
            new Template("Bengaluru", "Chennai", 4, BusType.NON_AC_SEATER, "13:30", 390, 480, 50),
            new Template("Bengaluru", "Chennai", 2, BusType.AC_SLEEPER, "23:00", 390, 990, 30),
            new Template("Bengaluru", "Chennai", 1, BusType.NON_AC_SLEEPER, "22:30", 390, 780, 92),
            new Template("Chennai", "Bengaluru", 5, BusType.AC_SEATER, "06:30", 390, 700, 25),
            new Template("Chennai", "Bengaluru", 3, BusType.NON_AC_SEATER, "14:00", 390, 470, 40),
            new Template("Chennai", "Bengaluru", 0, BusType.AC_SLEEPER, "23:30", 390, 1000, 45),
            new Template("Hyderabad", "Vijayawada", 4, BusType.AC_SEATER, "06:00", 300, 580, 20),
            new Template("Hyderabad", "Vijayawada", 1, BusType.NON_AC_SEATER, "10:30", 300, 410, 55),
            new Template("Hyderabad", "Vijayawada", 0, BusType.AC_SLEEPER, "22:30", 300, 850, 35),
            new Template("Hyderabad", "Vijayawada", 3, BusType.NON_AC_SLEEPER, "23:30", 300, 650, 100), // sold out
            new Template("Vijayawada", "Hyderabad", 2, BusType.AC_SEATER, "07:30", 300, 590, 30),
            new Template("Vijayawada", "Hyderabad", 5, BusType.AC_SLEEPER, "22:00", 300, 880, 40),
            new Template("Delhi", "Jaipur", 4, BusType.AC_SEATER, "06:00", 330, 750, 25),
            new Template("Delhi", "Jaipur", 0, BusType.NON_AC_SEATER, "08:30", 330, 520, 50),
            new Template("Delhi", "Jaipur", 5, BusType.AC_SLEEPER, "22:00", 330, 1150, 30),
            new Template("Delhi", "Jaipur", 1, BusType.NON_AC_SLEEPER, "23:00", 330, 880, 91),
            new Template("Jaipur", "Delhi", 2, BusType.AC_SEATER, "07:00", 330, 760, 30),
            new Template("Jaipur", "Delhi", 3, BusType.NON_AC_SEATER, "15:00", 330, 500, 60),
            new Template("Mumbai", "Pune", 4, BusType.AC_SEATER, "06:00", 210, 450, 20),
            new Template("Mumbai", "Pune", 0, BusType.AC_SEATER, "14:30", 210, 480, 45),
            new Template("Mumbai", "Pune", 1, BusType.NON_AC_SEATER, "17:00", 210, 320, 65),
            new Template("Mumbai", "Pune", 5, BusType.AC_SLEEPER, "22:30", 210, 750, 30),
            new Template("Pune", "Mumbai", 2, BusType.AC_SEATER, "07:30", 210, 460, 25),
            new Template("Pune", "Mumbai", 3, BusType.NON_AC_SEATER, "18:00", 210, 330, 55));

    /** Used when a place has no hand-picked bus-station name. */
    private static String boardingPoint(String city) {
        return BOARDING.getOrDefault(city, city + " Bus Stand");
    }

    private static String droppingPoint(String city) {
        return DROPPING.getOrDefault(city, city + " Bus Stand");
    }

    /**
     * Hand-written templates first, then three or four generated daily departures per direction for every
     * route in demo-routes.csv. The order fixes the bus numbers (DEMO-BUS-001, ...), so new routes are only
     * ever appended and existing buses keep their numbers.
     */
    private static List<Template> buildTemplates(List<DemoRouteCatalog.Route> routes) {
        List<Template> all = new ArrayList<>(CORE_TEMPLATES);
        int op = 0;
        for (DemoRouteCatalog.Route r : routes) {
            for (boolean forward : new boolean[]{true, false}) {
                String from = forward ? r.a() : r.b();
                String to = forward ? r.b() : r.a();
                String[] times = forward ? new String[]{"06:30", "14:00", "21:30", "23:00"}
                                         : new String[]{"07:30", "15:00", "22:00", "23:30"};
                all.add(new Template(from, to, op++ % 6, BusType.AC_SEATER, times[0], r.minutes(), r.baseFare(), 25));
                all.add(new Template(from, to, op++ % 6, BusType.NON_AC_SEATER, times[1], r.minutes(),
                        Math.round(r.baseFare() * 0.75f / 10) * 10, 50));
                all.add(new Template(from, to, op++ % 6, BusType.AC_SLEEPER, times[2], r.minutes(),
                        Math.round(r.baseFare() * 1.4f / 10) * 10, 35));
                if (r.minutes() >= 480) { // long routes also get a nearly full overnight sleeper
                    all.add(new Template(from, to, op++ % 6, BusType.NON_AC_SLEEPER, times[3], r.minutes(),
                            Math.round(r.baseFare() * 1.1f / 10) * 10, 92));
                }
            }
        }
        return List.copyOf(all);
    }

    private final OperatorRepository operatorRepository;
    private final BusRepository busRepository;
    private final TripRepository tripRepository;
    private final JdbcTemplate jdbcTemplate;
    private final TransactionTemplate transactions;
    private final List<Template> templates;

    /**
     * @param includeGeneratedRoutes false = only the hand-picked routes (used by the tests, which would otherwise
     *                               create tens of thousands of seat rows for every test).
     */
    public DemoDataService(OperatorRepository operatorRepository, BusRepository busRepository,
                           TripRepository tripRepository, JdbcTemplate jdbcTemplate, DemoRouteCatalog routeCatalog,
                           PlatformTransactionManager transactionManager,
                           @org.springframework.beans.factory.annotation.Value("${app.demo.include-generated-routes:true}")
                           boolean includeGeneratedRoutes) {
        this.operatorRepository = operatorRepository;
        this.busRepository = busRepository;
        this.tripRepository = tripRepository;
        this.jdbcTemplate = jdbcTemplate;
        this.transactions = new TransactionTemplate(transactionManager);
        this.templates = buildTemplates(routeCatalog.routes(includeGeneratedRoutes));
    }

    /** Deletes ALL bookings, trips, seats, buses and operators (users are kept), then re-seeds. */
    @Transactional
    public void reset() {
        // Children first, because of foreign keys.
        jdbcTemplate.update("DELETE FROM booking_seats");
        jdbcTemplate.update("DELETE FROM bookings");
        jdbcTemplate.update("DELETE FROM trip_seats");
        jdbcTemplate.update("DELETE FROM trips");
        jdbcTemplate.update("DELETE FROM buses");
        jdbcTemplate.update("DELETE FROM operators");
        seedUpcomingTrips();
    }

    /**
     * Adds whatever is missing for the next DAYS_AHEAD days. Safe to run repeatedly.
     * Each bus is saved in its own short transaction (not one huge one), so trips become searchable as soon as
     * they are written, the hand-picked routes (first in the list) appear within minutes even on a slow remote
     * database, and a restart keeps the progress already made. (reset() still wraps everything in one transaction.)
     */
    public int seedUpcomingTrips() {
        List<Operator> operators = transactions.execute(status -> {
            List<Operator> list = new ArrayList<>();
            for (OperatorSpec spec : OPERATORS) {
                list.add(operatorRepository.findByName(spec.name())
                        .orElseGet(() -> operatorRepository.save(new Operator(spec.name(), new BigDecimal(spec.rating())))));
            }
            return list;
        });

        int created = 0;
        for (int i = 0; i < templates.size(); i++) {
            final int index = i;
            Integer added = transactions.execute(status -> seedTemplate(index, operators));
            created += added == null ? 0 : added;
        }
        return created;
    }

    private int seedTemplate(int i, List<Operator> operators) {
        int created = 0;
        LocalDate today = LocalDate.now();
        Template t = templates.get(i);
        List<SeatSpec> layout = layoutFor(t.type());
        String registration = String.format("DEMO-BUS-%03d", i + 1);
        Bus bus = busRepository.findByRegistrationNumber(registration)
                .orElseGet(() -> busRepository.save(new Bus(operators.get(t.operator()), registration, t.type(), layout.size())));

        // Self-healing: if a route was renamed in the data files (e.g. Goa became Panaji), fix this bus's
        // existing trips instead of leaving old names behind or skipping them as "already created".
        jdbcTemplate.update("UPDATE trips SET source = ?, destination = ?, boarding_point = ?, dropping_point = ? "
                        + "WHERE bus_id = ? AND (source <> ? OR destination <> ?)",
                t.source(), t.destination(), boardingPoint(t.source()), droppingPoint(t.destination()),
                bus.getId(), t.source(), t.destination());

        // One query per bus (instead of one per day) to learn which days already have a trip.
        Set<LocalDateTime> existing = new HashSet<>(tripRepository.departureTimesFrom(bus.getId(), today.atStartOfDay()));
        for (int day = 0; day < daysAhead; day++) {
            LocalDateTime departure = today.plusDays(day).atTime(LocalTime.parse(t.departure()));
            if (existing.contains(departure)) {
                continue;
            }
            Trip trip = tripRepository.save(new Trip(bus, t.source(), t.destination(), departure,
                    departure.plusMinutes(t.durationMinutes()), BigDecimal.valueOf(t.fare()),
                    boardingPoint(t.source()), droppingPoint(t.destination())));
            insertSeats(trip, layout, t.bookedPercent());
            created++;
        }
        return created;
    }

    /** Bulk-inserts the seat inventory for one trip; some seats start BOOKED (pre-sold demo seats). */
    private void insertSeats(Trip trip, List<SeatSpec> layout, int bookedPercent) {
        int bookedCount = (int) Math.round(layout.size() * bookedPercent / 100.0);
        List<Integer> order = new ArrayList<>();
        for (int i = 0; i < layout.size(); i++) {
            order.add(i);
        }
        Collections.shuffle(order, new Random(trip.getId())); // deterministic per trip
        boolean[] booked = new boolean[layout.size()];
        for (int i = 0; i < bookedCount; i++) {
            booked[order.get(i)] = true;
        }
        jdbcTemplate.batchUpdate(
                "INSERT INTO trip_seats (trip_id, seat_number, deck, seat_row, seat_col, status) VALUES (?, ?, ?, ?, ?, ?)",
                IntStream.range(0, layout.size()).mapToObj(i -> {
                    SeatSpec s = layout.get(i);
                    return new Object[]{trip.getId(), s.number(), s.deck().name(), s.row(), s.col(),
                            booked[i] ? "BOOKED" : "AVAILABLE"};
                }).toList());
    }

    /**
     * Seater: one deck, 10 rows x 4 columns (2+2), numbers like 3B = 40 seats.
     * Sleeper: two decks, 5 rows x 3 columns (1+2) each, numbers like L2A / U4C = 30 berths.
     */
    private List<SeatSpec> layoutFor(BusType type) {
        List<SeatSpec> seats = new ArrayList<>();
        if (type.isSleeper()) {
            for (Deck deck : Deck.values()) {
                String prefix = deck == Deck.LOWER ? "L" : "U";
                for (int row = 1; row <= 5; row++) {
                    for (int col = 1; col <= 3; col++) {
                        seats.add(new SeatSpec(prefix + row + (char) ('A' + col - 1), deck, row, col));
                    }
                }
            }
        } else {
            for (int row = 1; row <= 10; row++) {
                for (int col = 1; col <= 4; col++) {
                    seats.add(new SeatSpec(row + "" + (char) ('A' + col - 1), Deck.LOWER, row, col));
                }
            }
        }
        return seats;
    }
}
