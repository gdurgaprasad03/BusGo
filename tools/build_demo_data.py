#!/usr/bin/env python3
"""
Builds BusGo's city catalog and demo-route data files from the GeoNames "cities5000" dump.

WHY THIS EXISTS
  * The city list lets users search places across all 28 states and 8 union territories of India.
  * The demo-route list says which pairs of cities have FICTIONAL demo bus services. Having a city in
    the catalog does NOT mean buses run to it. Only the routes in demo-routes.csv have demo trips.

DATA SOURCE AND LICENSE
  GeoNames (https://www.geonames.org), file cities5000.zip + admin1CodesASCII.txt.
  Licensed under Creative Commons Attribution 4.0 (https://creativecommons.org/licenses/by/4.0/).
  Attribution is shown in the app under Help & Support > "About & data credits", and in the README.

HOW TO UPDATE (about once a year is plenty)
  1. Download https://download.geonames.org/export/dump/cities5000.zip and unzip it.
  2. Download https://download.geonames.org/export/dump/admin1CodesASCII.txt
  3. python tools/build_demo_data.py --cities cities5000.txt --admin1 admin1CodesASCII.txt
  4. Run the backend and Flutter tests, then commit the regenerated CSV files.

OUTPUT (written to the backend resources and copied to the Flutter assets)
  india-cities.csv         name,state,lat,lon,population      (one row per unique city name)
  india-states.csv         name,type                            (STATE or UNION_TERRITORY)
  india-city-aliases.csv   alias,city                           (Bangalore -> Bengaluru, Goa -> Panaji, ...)
  demo-routes.csv          a,b,minutes,baseFare,kind            (each row is served in BOTH directions)

Only the standard library is used. The output is deterministic (same input -> same files).
"""
import argparse
import csv
import math
import os
from collections import defaultdict

UNION_TERRITORIES = {
    "Andaman and Nicobar", "Chandigarh", "Dadra and Nagar Haveli and Daman and Diu", "Delhi",
    "Jammu and Kashmir", "Ladakh", "Lakshadweep", "Puducherry",
}
# Islands: no road link to the mainland, so no demo bus routes are generated for them.
ISLAND_STATES = {"Andaman and Nicobar", "Lakshadweep"}

# GeoNames spellings we prefer to show differently.
RENAMES = {"Rajamahendravaram": "Rajahmundry", "Panjim": "Panaji"}

# Old / alternative names people still type. Each must point at a city in the catalog.
ALIASES = {
    "Bangalore": "Bengaluru", "Mysore": "Mysuru", "Vizag": "Visakhapatnam", "Vishakhapatnam": "Visakhapatnam",
    "Bombay": "Mumbai", "Madras": "Chennai", "Calcutta": "Kolkata", "Cochin": "Kochi",
    "Trivandrum": "Thiruvananthapuram", "Gurgaon": "Gurugram", "Allahabad": "Prayagraj", "Baroda": "Vadodara",
    "Poona": "Pune", "Pondicherry": "Puducherry", "Mahabubnagar": "Mahbubnagar", "Cuddapah": "Kadapa",
    "Rajamahendravaram": "Rajahmundry", "Panjim": "Panaji", "Goa": "Panaji", "Belgaum": "Belagavi",
    "Mangalore": "Mangaluru", "Hubli": "Hubballi", "Bhubaneshwar": "Bhubaneswar", "Benares": "Varanasi",
    "Banaras": "Varanasi", "Simla": "Shimla", "Trichy": "Tiruchirappalli", "Tiruchchirappalli": "Tiruchirappalli",
    "Udaipur City": "Udaipur", "New Delhi": "Delhi", "Pune City": "Pune", "Ernakulam": "Kochi",
    "Vijayawada City": "Vijayawada", "Guwahati City": "Guwahati", "Warrangal": "Warangal",
}

# The hand-picked routes the app has always had (kept first, in this order, so existing bus numbers
# never change). The core routes below are defined in the backend/Dart code with hand-tuned times;
# they are listed here only so the generator does not create duplicates of them.
CORE_PAIRS = [
    ("Kurnool", "Hyderabad"), ("Hyderabad", "Bengaluru"), ("Bengaluru", "Chennai"),
    ("Hyderabad", "Vijayawada"), ("Delhi", "Jaipur"), ("Mumbai", "Pune"),
]
CURATED = [  # a, b, minutes, base AC-seater fare
    ("Kurnool", "Bengaluru", 420, 700), ("Hyderabad", "Visakhapatnam", 660, 1250),
    ("Vijayawada", "Visakhapatnam", 420, 700), ("Chennai", "Tirupati", 210, 400),
    ("Bengaluru", "Tirupati", 300, 560), ("Bengaluru", "Mysuru", 210, 380),
    ("Bengaluru", "Coimbatore", 360, 650), ("Chennai", "Madurai", 480, 850),
    ("Mumbai", "Panaji", 600, 1300), ("Mumbai", "Ahmedabad", 540, 1000),
    ("Delhi", "Chandigarh", 240, 520), ("Delhi", "Agra", 240, 480),
    ("Pune", "Panaji", 540, 1100), ("Jaipur", "Ahmedabad", 540, 1050),
    ("Warangal", "Kurnool", 480, 800), ("Warangal", "Hyderabad", 180, 350),
    ("Warangal", "Vijayawada", 240, 450), ("Warangal", "Bengaluru", 780, 1200),
    ("Karimnagar", "Hyderabad", 210, 380), ("Nizamabad", "Hyderabad", 240, 420),
    ("Guntur", "Hyderabad", 300, 520), ("Guntur", "Vijayawada", 90, 200),
    ("Nellore", "Chennai", 300, 520), ("Nellore", "Tirupati", 210, 380),
    ("Rajahmundry", "Visakhapatnam", 270, 480), ("Rajahmundry", "Vijayawada", 240, 420),
    ("Anantapur", "Bengaluru", 270, 520), ("Anantapur", "Kurnool", 180, 330),
    ("Kadapa", "Tirupati", 150, 300), ("Kadapa", "Kurnool", 150, 300),
    ("Mahbubnagar", "Hyderabad", 120, 250), ("Mahbubnagar", "Kurnool", 120, 250),
    ("Hyderabad", "Chennai", 660, 1250),
]

ROAD_FACTOR = 1.3        # road distance is about 1.3 x the straight-line distance
AVG_SPEED_KMH = 55
FARE_PER_ROAD_KM = 2.2   # demo AC-seater fare
MIN_ROUTE_KM, MAX_ROUTE_KM, MAX_METRO_KM = 60, 900, 1200
MAX_BASE_FARE = 2000     # sleeper = base * 1.4 stays below the app's 3000 slider maximum
METROS, METRO_LINKS = 20, 2


def haversine_km(a, b):
    r = 6371.0
    p1, p2 = math.radians(a["lat"]), math.radians(b["lat"])
    dphi, dlmb = p2 - p1, math.radians(b["lon"] - a["lon"])
    h = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlmb / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h))


def round_to(value, step):
    return int(round(value / step) * step)


def load_cities(cities_path, admin1_path):
    states = {}
    with open(admin1_path, encoding="utf-8") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if parts[0].startswith("IN."):
                states[parts[0][3:]] = parts[1]
    best = {}  # ascii name -> city. A name used in several states keeps its largest city.
    with open(cities_path, encoding="utf-8") as f:
        for line in f:
            p = line.rstrip("\n").split("\t")
            if p[8] != "IN" or p[10] not in states:
                continue
            name = RENAMES.get(p[2].strip(), p[2].strip())
            city = {"name": name, "state": states[p[10]], "lat": float(p[4]), "lon": float(p[5]), "pop": int(p[14])}
            if name not in best or city["pop"] > best[name]["pop"]:
                best[name] = city
    return sorted(best.values(), key=lambda c: c["name"].lower()), sorted(states.values())


def plan_routes(cities):
    by_name = {c["name"]: c for c in cities}
    known = {frozenset(p) for p in CORE_PAIRS} | {frozenset((a, b)) for a, b, _, _ in CURATED}
    for a, b, _, _ in CURATED:
        assert a in by_name and b in by_name, f"curated route uses an unknown city: {a} / {b}"
    by_state = defaultdict(list)
    for c in sorted(cities, key=lambda c: (-c["pop"], c["name"])):
        by_state[c["state"]].append(c)
    routes = {}

    def add(a, b, kind, cap=MAX_ROUTE_KM):
        if a["name"] == b["name"] or a["state"] in ISLAND_STATES or b["state"] in ISLAND_STATES:
            return
        key = frozenset((a["name"], b["name"]))
        if key in known or key in routes:
            return
        km = haversine_km(a, b) * ROAD_FACTOR
        if km < MIN_ROUTE_KM or km > cap:
            return
        minutes = max(60, round_to(km / AVG_SPEED_KMH * 60, 5))
        fare = min(MAX_BASE_FARE, max(150, round_to(km * FARE_PER_ROAD_KM, 10)))
        routes[key] = (a["name"], b["name"], minutes, fare, kind)

    # 1) Inside each state: its largest city to the next two.
    for state in sorted(by_state):
        hub, others = by_state[state][0], by_state[state][1:]
        for other in others[:6]:
            if len([r for r in routes.values() if r[4] == "INTRASTATE" and hub["name"] in r[:2]]) >= 2:
                break
            add(hub, other, "INTRASTATE")

    # 2) Between states: each state's largest city to the nearest two hubs of other states.
    hubs = [by_state[s][0] for s in sorted(by_state) if s not in ISLAND_STATES]
    for hub in hubs:
        nearest = sorted((h for h in hubs if h["state"] != hub["state"]), key=lambda h: haversine_km(hub, h))
        for other in nearest[:2]:
            add(hub, other, "INTERSTATE")

    # 3) Metro mesh: the biggest cities to their nearest big neighbours (long-distance trunk routes).
    metros = sorted((c for c in cities if c["state"] not in ISLAND_STATES), key=lambda c: -c["pop"])[:METROS]
    for m in metros:
        nearest = sorted((x for x in metros if x["name"] != m["name"]), key=lambda x: haversine_km(m, x))
        for other in nearest[:METRO_LINKS]:
            add(m, other, "METRO", cap=MAX_METRO_KM)

    return sorted(routes.values(), key=lambda r: (r[4], r[0], r[1]))


def write_csv(path, header, rows):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(header)
        w.writerows(rows)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cities", required=True, help="path to cities5000.txt")
    ap.add_argument("--admin1", required=True, help="path to admin1CodesASCII.txt")
    ap.add_argument("--out", action="append", help="output folder(s); default: backend resources + Flutter assets")
    args = ap.parse_args()
    root = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    outs = args.out or [
        os.path.join(root, "backend", "src", "main", "resources", "data"),
        os.path.join(root, "frontend", "assets", "data"),
    ]

    cities, state_names = load_cities(args.cities, args.admin1)
    by_name = {c["name"] for c in cities}
    aliases = [(a, c) for a, c in sorted(ALIASES.items()) if c in by_name and a not in by_name]
    skipped = [a for a, c in ALIASES.items() if c not in by_name]
    generated = plan_routes(cities)
    curated_rows = [(a, b, m, f, "CURATED") for a, b, m, f in CURATED]

    for out in outs:
        write_csv(os.path.join(out, "india-cities.csv"), ["name", "state", "lat", "lon", "population"],
                  [(c["name"], c["state"], f'{c["lat"]:.4f}', f'{c["lon"]:.4f}', c["pop"]) for c in cities])
        write_csv(os.path.join(out, "india-states.csv"), ["name", "type"],
                  [(s, "UNION_TERRITORY" if s in UNION_TERRITORIES else "STATE") for s in state_names])
        write_csv(os.path.join(out, "india-city-aliases.csv"), ["alias", "city"], aliases)
        write_csv(os.path.join(out, "demo-routes.csv"), ["a", "b", "minutes", "baseFare", "kind"],
                  curated_rows + generated)

    covered = defaultdict(set)
    city_state = {c["name"]: c["state"] for c in cities}
    for a, b, *_ in curated_rows + generated:
        covered[city_state[a]].add(a)
        covered[city_state[b]].add(b)
    print(f"cities: {len(cities)}  states/UTs: {len(state_names)}  aliases: {len(aliases)}  skipped aliases: {skipped}")
    print(f"demo routes: {len(curated_rows)} curated + {len(generated)} generated (each runs in both directions)")
    print("states/UTs without any demo route:", sorted(set(state_names) - set(covered)))


if __name__ == "__main__":
    main()
