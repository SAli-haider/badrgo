# badrgo Ops Console — Flutter Web Operations Dashboard

[![Flutter Version](https://img.shields.io/badge/Flutter-3.41.9-blue.svg)](https://flutter.dev)
[![Architecture](https://img.shields.io/badge/Architecture-Clean%20MVVM%20with%20BLoC-success.svg)](https://bloclibrary.dev)
[![Tests](https://img.shields.io/badge/Tests-73%20passed%20%E2%9C%93-brightgreen.svg)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-Proprietary-orange.svg)](#)

A high-performance operations control console built for **badrgo** city operations teams across **Doha**, **Al Rayyan**, and **Al Wakrah**. The console delivers real-time visibility and active dispatch capabilities over simulated city transport operations, supporting role-based access control (RBAC), multi-transport architecture (REST, GraphQL, SSE, WebSocket), and instant response to live fleet emergencies.

> [!IMPORTANT]
> - 🎥 **Submission Video Walkthrough:** [Watch the Operations Walkthrough Recording on Google Drive](https://drive.google.com/file/d/1Cge1bXgT-0eZbw9IknXKHs5egiHh50-F/view?usp=sharing)
> - 🖥️ **Display / Viewport Note:** The console is currently tailored and optimized strictly for **Desktop Web & Operations Control Center Displays** (1280px+ desktop resolutions used by city dispatch teams). **It is currently NOT mobile responsive**; mobile viewport reflow and phone drawer adaptations are prioritized for future iterations.

---

## 📋 Table of Contents
- [Quick Start & Setup](#-quick-start--setup)
- [Submission Video & Viewport Note](#-submission-video--viewport-note)
- [Demo Accounts & Credentials](#-demo-accounts--credentials)
- [Architecture: Clean MVVM with BLoC](#-architecture-clean-mvvm-with-bloc)
- [Which Transport for What](#-which-transport-for-what)
- [Core Must-Haves (M1–M7) Implementation](#-core-must-haves-m1m7-implementation)
- [Role-Based Access Control (RBAC) Matrix](#-role-based-access-control-rbac-matrix)
- [Key Technical Decisions & Trade-Offs](#-key-technical-decisions--trade-offs)
- [Discovered API Anomalies & Feedback](#-discovered-api-anomalies--feedback)
- [Future Enhancements (With More Time)](#-future-enhancements-with-more-time)
- [Testing & Quality Assurance](#-testing--quality-assurance)

---

## 🚀 Quick Start & Setup

### Prerequisites
- **Flutter SDK:** `3.41.9` (stable channel)
- **Dart SDK:** `^3.11.5`
- **Browser:** Google Chrome (recommended for Flutter Web)

### Running the App
1. **Clone the repository:**
   ```bash
   git clone https://github.com/SAli-haider/badrgo.git
   cd badrgo
   ```

2. **Install project dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app in Chrome with compile-time API URL configuration:**
   ```bash
   flutter run -d chrome --dart-define=API_URL=https://sandbox.badrgo.com
   ```

4. **Run static analysis and automated test suite:**
   ```bash
   dart analyze
   flutter test
   ```

5. **Production Web Build:**
   ```bash
   flutter build web --release --dart-define=API_URL=https://sandbox.badrgo.com
   ```

> [!NOTE]
> The sandbox API URL is strictly configurable via `--dart-define=API_URL=...` with zero secrets hardcoded in the repository, satisfying the `ENV-1` configuration guideline.

---

## 👥 Demo Accounts & Credentials

All demo accounts use the standard password: **`Demo@12345`**

| Email | Role | City | Permissions Overview |
| :--- | :--- | :--- | :--- |
| `superadmin@demo.test` | `super_admin` | All Cities | Full system access, multi-city oversight, user administration |
| `ops.doha@demo.test` | `ops_manager` | Doha | Fleet operations, full driver/rider management, trip actions |
| `dispatch.doha@demo.test` | `dispatcher` | Doha | Live dispatch, driver assignment, trip cancellation |
| `support.doha@demo.test` | `support` | Doha | Trip inspection, refund issuance (no live map, no KPIs) |
| `viewer.doha@demo.test` | `viewer` | Doha | Read-only analytics, phone numbers masked (`+974 •••• 1234`) |
| `ops.rayyan@demo.test` | `ops_manager` | Al Rayyan | Operations manager for Al Rayyan zone |
| `dispatch.wakrah@demo.test` | `dispatcher` | Al Wakrah | Dispatcher for Al Wakrah zone |

> [!TIP]
> A **Quick Demo Account Switcher** is provided directly on the Login Screen. One tap automatically fills the email and password for any role to facilitate effortless reviewer evaluation.

---

## 🏛️ Architecture: Clean MVVM with BLoC

The codebase strictly adheres to **Clean Architecture** organized by feature modules, maintaining an inward-only dependency flow (`View` → `ViewModel` → `Domain` ← `Data`):

```
┌─────────────────────────────────────────────────────────────┐
│                       PRESENTATION                          │
│   View (Widgets): Pure UI rendering, zero transport code    │
│                           │                                 │
│                           ▼                                 │
│   ViewModel (BLoC/Cubit): UI State, RBAC, Event Handling    │
└───────────────────────────┬─────────────────────────────────┘
                            │ Calls Interfaces Only
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                          DOMAIN                             │
│   Entities: Pure Dart models, zero HTTP/UI dependencies     │
│   Repository Interfaces: Abstract contracts for data access │
└───────────────────────────▲─────────────────────────────────┘
                            │ Implements Interfaces
┌─────────────────────────────────────────────────────────────┐
│                           DATA                              │
│   Repository Implementations: Orchestrates network & cache  │
│   Clients: RestClient, GraphQLClient, SseClient, WsClient   │
│   DTO Models: JSON serialization & error envelope parsing   │
└─────────────────────────────────────────────────────────────┘
```

### Directory Structure
```text
lib/
├── app.dart                                # MaterialApp.router & Root Bloc Providers
├── main.dart                               # Concise composition root (DI bootstrap)
├── core/
│   ├── config/                             # AppConfig (--dart-define=API_URL)
│   ├── di/                                 # AppDependencies container & event wiring
│   ├── network/                            # Network transport clients
│   │   ├── api_result.dart                 # Sealed functional ApiResult<T>
│   │   ├── app_exception.dart              # Mapped error codes (UNAUTHENTICATED, etc.)
│   │   ├── graphql/                        # Lightweight GraphQL HTTP client
│   │   ├── rest/                           # REST client with auth headers & error interceptor
│   │   ├── sse/                            # SSE client using package:web EventSource
│   │   └── ws/                             # WebSocket client with backoff reconnect
│   ├── router/                             # GoRouter config with RBAC guards
│   ├── storage/                            # SessionStorage (localStorage)
│   ├── theme/                              # Dark theme palette & typography
│   ├── utils/                              # Phone maskers, currency & date formatters
│   └── widgets/                            # Reusable OpsCard, OpsBadge, ErrorView, etc.
└── features/
    ├── alerts/                             # Realtime alerts feed & SOS management
    ├── auth/                               # Sign-in, session restore, token revocation
    ├── dashboard/                          # Operational KPIs & trips series chart
    ├── health/                             # Health monitoring & 503 maintenance
    ├── map/                                # Live driver map (WebSocket & OSM)
    ├── shell/                              # Shell scaffold, navigation sidebar & Global SOS
    └── trips/                              # Cursor pagination, nested details & actions
```

---

## 🌐 Which Transport for What

Each network transport is dedicated strictly to its assigned responsibility as mandated by the assessment requirements:

| Transport | Dedicated Responsibility | Implementation Details & Package Justification |
| :--- | :--- | :--- |
| **REST** | Authentication, `/api/me`, and write operations (assign, cancel, refund, acknowledge) | Built using `package:http`. Implements standard Bearer token interceptor, centralized 401 broadcast, and error envelope parsing (`{ error: { code, message, details } }`). |
| **GraphQL** | Dashboard KPIs, trips series chart, paginated trips list, nested trip details | Built via a dedicated `GraphQLClient` executing over HTTP. Formulates single unified queries to avoid N+1 waterfalls (e.g. fetching trip with nested rider, driver, and city in one round-trip). |
| **SSE** (`/api/events`) | Live KPI tiles, alerts feed, real-time trip list updates | Built using `package:web` (`EventSource`) with `?token=<token>`. Modern, future-proof standard recommended by the Flutter team over deprecated `dart:html`. Handles `deniedTopics` gracefully. |
| **WebSocket** (`/ws`) | Live driver locations map (`drivers.locations` channel) | Built using `web_socket_channel` with `?token=<token>`. Protocol envelope adheres to `{ type: "subscribe", payload: { channel: "drivers.locations" } }`. Implements exponential backoff reconnects (1s → 2s → 4s → 8s → 16s → 30s). |

---

## 🛠️ Core Must-Haves (M1–M7) Implementation

### M1. Authentication & Session Engine
- **Sign-In:** Clean login screen displaying server-side validation and banned user errors directly on fields.
- **Session Persistence:** Tokens and user metadata persist across browser page refreshes in `SessionStorage`.
- **Token Revocation:** User logout initiates `POST /api/auth/sign-out` to revoke the token on the server before clearing client storage.
- **Non-Looping 401 Guard:** Any 401 response from REST, GraphQL, SSE, or WebSocket shuts down real-time connections and redirects to `/login` without trigger loops.

### M2. Role-Aware Shell & RBAC
- **Permission-Driven:** Navigation items, routes, and action controls derive strictly from `/api/me` permissions (e.g., `trip:assign`, `driver:track`, `kpi:read`), never from hardcoded role strings.
- **Access Denied Fallback:** Direct URL tampering routes to an `AccessDeniedScreen` explaining missing permissions rather than crashing.
- **Top Shell Header:** Displays current operator's name, assigned city badge, and role pill.

### M3. Operations Dashboard
- **KPI Tiles:** Loads initial operational metrics via GraphQL `kpis` and updates live values seamlessly via SSE `kpi` events.
- **Multi-Currency Revenue:** Correctly handles `revenue` as a list of currencies (e.g., `QAR`), rendering formatted amounts.
- **Volume Chart:** Interactive `fl_chart` plotting trip volume over time with a toggle between **Last 24 Hours** and **Last 7 Days**.

### M4. Trips Management & Actions
- **Cursor Pagination:** Smooth forward pagination using GraphQL cursor query.
- **Filter Bar:** Real-time filtering by status, search string, and date ranges.
- **Live Row Highlighting:** Incoming SSE `trip.created` and `trip.updated` events prepend or mutate list items without full page reloads, accompanied by visual badge indicators.
- **Single Nested Detail Query:** Displays rider, driver, pickup/dropoff places, fare, refund history, and status timeline.
- **Permitted Actions:**
  - *Assign Driver:* Modal listing available drivers.
  - *Cancel Trip:* Modal requiring reason selection and notes. Handles 409 `INVALID_STATE` cleanly if the simulator updates trip status concurrently.
  - *Issue Refund:* Validates refund amount against remaining balance with reason input.

### M5. Live Driver Map
- **WebSocket Streaming:** Subscribes to `drivers.locations` channel; decodes snapshot payloads every ~2 seconds.
- **OpenStreetMap & `flutter_map`:** Lightweight, responsive tile rendering with status-coded markers (Available: Green, On Trip: Blue, Busy: Orange) with bearing rotations.
- **Driver Detail Modal:** Clicking a driver displays vehicle info, rating, masked phone numbers (for `viewer`), and active trip inspector links.
- **Resilient Reconnection:** Exponential backoff with a visible "Connecting / Reconnecting" status badge. Tab-switching pause/resume protection.

### M6. Realtime Alerts & Global SOS Banner
- **Alerts Feed:** Live feed connected to SSE `alert.created` and `alert.acknowledged`.
- **App-Wide SOS Banner:** Any `critical` SOS emergency triggers a prominent top banner across all tabs.
- **Instant Dismissal & Multi-Alert Carousel:** Clicking close `[X]` dismisses the banner immediately until a new emergency occurs, with carousel controls (`< 1/3 >`) when multiple emergencies exist.
- **Acknowledge Action:** RBAC-guarded one-click acknowledge (`alert:acknowledge`) with optimistic UI updates.

### M7. Maintenance & Resilience
- **503 Interceptor:** Intercepts 503 responses carrying `Retry-After` headers and `MAINTENANCE` error envelopes.
- **Maintenance Screen:** Keeps the operator signed in while presenting server maintenance reasons, elapsed downtime, and live retry counters.
- **Health Polling:** Polls `GET /api/health` with backoff; automatically recovers SSE, WebSocket, and stale data when `{ ok: true }` returns.
- **Connection Diagnostics:** Differentiates between a transient socket drop (subtle toast) and a full server maintenance outage.

---

## 🔒 Role-Based Access Control (RBAC) Matrix

| Feature / Action | Required Permission | `super_admin` | `ops_manager` | `dispatcher` | `support` | `viewer` |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: |
| **View Dashboard & KPIs** | `kpi:read` | ✅ | ✅ | ✅ | ❌ | ✅ |
| **View Trips List & Details** | `trip:read` | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Assign Driver to Trip** | `trip:assign` | ✅ | ✅ | ✅ | ❌ | ❌ |
| **Cancel Active Trip** | `trip:cancel` | ✅ | ✅ | ✅ | ❌ | ❌ |
| **Issue Trip Refund** | `trip:refund` | ✅ | ✅ | ❌ | ✅ | ❌ |
| **Live Driver Map** | `driver:track` | ✅ | ✅ | ✅ | ❌ | ❌ |
| **View Alerts Feed** | `alert:read` | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Acknowledge SOS Alert** | `alert:acknowledge` | ✅ | ✅ | ✅ | ❌ | ❌ |
| **Customer Phone Display** | Full Access | Full | Full | Full | Full | **Masked** |

---

## 💡 Key Technical Decisions & Trade-Offs

1. **Lightweight Custom Network Drivers over Bulky Frameworks:**
   - Rather than bundling heavy GraphQL and WebSocket frameworks with complex code generators, we implemented lean, purpose-built clients (`GraphQLClient`, `WsClient`, `SseClient`) utilizing `http`, `web`, and `web_socket_channel`. This keeps web bundle sizes small, compilation instant, and runtime performance snappy.
2. **`flutter_map` with OpenStreetMap vs Google Maps:**
   - Selected `flutter_map` with OSM tiles because it eliminates proprietary JavaScript SDK injections, API key leakage risks, and billing constraints in an open candidate sandbox environment.
3. **Single Nested GraphQL Queries:**
   - Designed GraphQL queries to fetch full nested hierarchies (Trip + Rider + Driver + City) in a single request, completely preventing N+1 waterfall latency on Flutter Web.
4. **Optimistic UI Updates with Rollback:**
   - Alerts acknowledgment and dispatch actions mutate state optimistically to deliver immediate feedback to operations personnel, gracefully rolling back and notifying if network calls fail.

---

## 🐛 Discovered API Anomalies & Feedback

*(Documented in candidate's favor per assessment guidelines)*

1. **WebSocket Subscription Protocol Discrepancy:**
   - In `/docs/realtime`, the subscription envelope format is documented as:
     ```json
     { "type": "subscribe", "payload": { "channel": "drivers.locations" } }
     ```
     Earlier informal examples referenced `{ "action": "subscribe" }`. Using the strictly documented `type` / `payload` structure proved necessary for driver location streaming.
2. **Cold Start 401 vs Unauthenticated Visits:**
   - When visiting the web application for the first time with an empty browser cache, invoking `/api/me` or `/api/alerts` before login emitted a spurious 401 error. We resolved this by implementing an explicit local storage check in `AuthCubit` that transitions cleanly to `Unauthenticated` without firing network calls or error banners.
3. **Simulator Concurrency Races (409 Conflict):**
   - The sandbox simulator occasionally completes or cancels trips while an operator is inspecting them. Handling 409 `INVALID_STATE` specifically with clear UI explanations and automated detail refreshes was necessary to prevent stuck loading states.
4. **Browser Tab Throttling on Flutter Web:**
   - Chrome aggressively throttles WebSocket and timers when tabs are switched or backgrounded. We added visibility lifecycle handling to reconnect gracefully and request fresh driver snapshots upon tab re-focus.

---

## 🔮 Future Enhancements (With More Time)

If additional engineering time were available, the following roadmap items would be prioritized:
- **Bonus B6 (Mobile & Tablet Responsiveness):** Refactor the fixed-sidebar desktop shell into collapsible drawers and responsive cards for small-screen phone form factors (the console currently targets desktop/control-room resolutions).
- **Bonus B1 (Driver Chat):** Implement the live chat drawer over WebSocket `driver.messages` channel and `GET /api/drivers/{id}/messages`.
- **Bonus B4 (Smart Reconnection):** Resume SSE streams with `Last-Event-ID` tracking so no transient events are missed during wifi handovers.
- **Bonus B5 (Arabic & RTL Support):** Complete bidirectional layout adaptation with `flutter_localizations` and an Arabic/English toggle.
- **Bonus B2 (User Management Portal):** Admin interface for `super_admin` to create users, modify permissions, and manage ban statuses.

---

## 🧪 Testing & Quality Assurance

The test suite covers domain logic, serialization, and role-based widget rendering:

```bash
flutter test
```

### Test Suite Highlights
- **RBAC Matrix Tests:** Verifies permission resolution and access barriers for all 7 demo accounts.
- **Role-Gated Widget Tests:** Tests that action buttons (Assign, Refund, Acknowledge) are present for authorized roles and absent for `viewer` or unauthorized roles.
- **Data & DTO Tests:** Tests JSON deserialization and error envelope parsing for REST and GraphQL models.
- **SOS Banner Tests:** Verifies prominent emergency rendering, carousel cycling, and instant dismissal behavior.

**Current Test Status:** `73 / 73 tests passing (100% clean)`.
