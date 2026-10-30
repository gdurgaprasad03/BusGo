# BusGo

A bus ticket booking app: a **Flutter** mobile app, a **Spring Boot 3.5** REST API and a **MySQL** database.

> **Demo project.** All buses, operators, schedules, ratings and fares are generated sample data, not live
> information. Payments are simulated; no real money is taken and no real tickets are issued.

## Features

- Register / log in (email or mobile number) with JWT authentication; optional Google sign-in
- Forgot password with a 6-digit emailed code (when email is configured)
- Search ~6,200 places in India, then search buses by source, destination and date; sort and filter results
- Seat selection (seater and sleeper layouts), passenger details, simulated payment, ticket with booking reference
- My bookings, cancellation with a demo refund policy, saved passengers, complaints, profile
- Booking emails (confirmation / cancellation) when email is configured

## Tech stack

| Part | Technology |
|---|---|
| Mobile app | Flutter (Material 3) |
| API | Spring Boot 3.5, Java 22, Spring Security (stateless JWT), Spring Data JPA |
| Database | MySQL 8 with Flyway migrations (H2 in MySQL mode for tests) |
| Email | SMTP (local) or Brevo HTTPS API (hosting) |
| Hosting used for the demo | Render (Docker) + Aiven MySQL |

## How booking stays correct

- A booking is one transaction; seats are locked with `SELECT ... FOR UPDATE`, so two people cannot book the same seat.
- Prices are calculated on the server, never trusted from the app.
- Users can only see and cancel their own bookings (403 otherwise).

## Live demo API

`https://busgo-4.onrender.com`

- Hosted on a free plan: after being idle the **first request can take about a minute** while the server wakes up.
- Health check: `GET /api/health`
- Example: `GET /api/places?query=Hyd`

## Run it locally

### Backend

Requirements: JDK 22 and a MySQL 8 database.

1. Create a database and a user for it.
2. Set these environment variables (or put them in `backend/application-local.properties`, which is git-ignored):

   | Variable | Meaning |
   |---|---|
   | `DB_URL` | e.g. `jdbc:mysql://localhost:3306/busgo?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC` |
   | `DB_USERNAME`, `DB_PASSWORD` | database login |
   | `JWT_SECRET` | random string, at least 32 characters |

3. Start it:

   ```
   cd backend
   ./mvnw spring-boot:run        # Windows: .\mvnw.cmd spring-boot:run
   ```

   Flyway creates the tables and demo trips are generated in the background on startup.

4. Run the tests: `./mvnw test`

### Mobile app

Requirements: Flutter SDK.

```
cd frontend
flutter pub get
flutter run                                   # Android emulator: uses http://10.0.2.2:8080
flutter run --dart-define=API_BASE_URL=http://<your-pc-ip>:8080     # real phone on the same Wi-Fi
flutter run --dart-define=API_BASE_URL=https://busgo-4.onrender.com --dart-define=API_TIMEOUT_SECONDS=90
flutter run --dart-define=OFFLINE_DEMO=true   # no backend needed: the app answers by itself with demo data
```

Run the app tests with `flutter test`.

## Optional features (off unless configured)

| Feature | Setting |
|---|---|
| Email | `MAIL_ENABLED=true`, then SMTP (`MAIL_HOST`, `MAIL_USERNAME`, ...) or `MAIL_PROVIDER=brevo` with `BREVO_API_KEY` and `MAIL_FROM` |
| Google sign-in | `GOOGLE_CLIENT_IDS` on the server and `--dart-define=GOOGLE_WEB_CLIENT_ID=...` in the app |
| Running behind a proxy | `FORWARD_HEADERS_STRATEGY=native` (so rate limiting sees real client addresses) |

Deployment steps for Render + Aiven + Brevo are in [docs/DEPLOY_RENDER.md](docs/DEPLOY_RENDER.md).
See `.env.example` for the variable names (placeholders only).

## API overview

| Area | Endpoints |
|---|---|
| Health | `GET /api/health` |
| Auth | `POST /api/auth/register`, `/login`, `/google`, `/forgot-password`, `/reset-password`; `GET /api/auth/config` |
| Places | `GET /api/places`, `GET /api/places/states` |
| Trips | `GET /api/trips/search?source=&destination=&date=`, `GET /api/trips/{id}`, `GET /api/trips/{id}/seats` |
| Bookings (login required) | `POST /api/bookings`, `GET /api/bookings/my`, `GET /api/bookings/{id}`, `PATCH /api/bookings/{id}/cancel` |
| Profile (login required) | `GET/PUT /api/users/me`, `/api/users/me/passengers` |
| Complaints (login required) | `POST /api/complaints`, `GET /api/complaints/my` |

Login-required endpoints need the header `Authorization: Bearer <token>` from the login response.

## Project layout

```
backend/    Spring Boot API (controller, service, repository, entity, security, mail, catalog, integration)
frontend/   Flutter app
tools/      build_demo_data.py: regenerates the places/routes data files
docs/       deployment guide
Dockerfile  builds the backend image (used by Render)
render.yaml Render service definition
```

## Limitations (honest notes)

- **No live bus data.** Real inventory needs a bus operator or aggregator partner API. The backend has a provider
  layer (`TripProvider`) where one could be added; today only the demo provider exists.
- There is no admin panel; demo trips are generated from `demo-routes.csv`.
- Payments are simulated.
- Free hosting sleeps when idle, and the full set of generated demo routes takes a while to appear after a fresh database.

## Data credits

Place names come from [GeoNames](https://www.geonames.org/) (cities5000), licensed
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
