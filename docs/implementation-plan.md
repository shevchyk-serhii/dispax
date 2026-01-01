# Oktopus Taxi - Implementation Plan

## Current Status Analysis

### ✅ Completed (Backend)
- **Authentication & Authorization**: JWT-based auth with User/Token repositories
- **Core Domain**: Person, Company, Location, RideId, PersonId, CompanyId
- **Ride Module**: Complete CRUD with statuses (Requested → Assigned → InProgress → Completed → Cancelled)
- **RideService**: Unified service with create, get, start, complete, cancel, updateStatus
- **Database**: PostgreSQL with Flyway migrations
- **API Structure**: Modular Onion Architecture (core, auth, ride, driver, notification modules)
- **Testing**: 646 tests passing (unit + integration + Cucumber BDD)

### ✅ Completed (Frontend - Flutter)
- **Multi-role Authentication**: Login system with Driver, Client, Secretary, Dispatcher
- **Real-time Mapping**: Mapbox integration with live tracking
- **Airport Optimization**: Entry timing, flight info, location clarification
- **Driver App**: Today's rides, calendar view, history, flights, map
- **Client App**: Active rides, history, driver tracking, flight management

### ⚠️ Partially Implemented
- **Secretary Dashboard**: Basic structure only
- **Dispatcher Dashboard**: Structure exists, needs assignment interface
- **Schedule Management**: Domain exists but not fully implemented
- **Driver Assignment**: Service stub exists but not functional

### ❌ Missing Core MVP Features
1. **Schedule & ScheduleDay** entities and operations
2. **Dispatcher Assignment Interface** (backend + frontend)
3. **Ride Assignment Logic** with schedule integration
4. **Driver Schedule CRUD** operations
5. **Real-time updates** (WebSocket/SSE)
6. **Location tracking** API endpoints
7. **Company isolation** enforcement in all operations

---

## MVP Implementation Plan

### Phase 1: Schedule Management Foundation (Week 1-2)
**Goal**: Enable drivers to have schedules and dispatchers to view them

#### Backend Tasks
1. **Schedule Domain & Repository**
   - [ ] Create `Schedule` and `ScheduleDay` entities in domain
   - [ ] Add `ScheduleRepository` interface
   - [ ] Implement `PostgresScheduleRepository`
   - [ ] Add Flyway migrations for schedule tables
   - [ ] Write unit tests for schedule domain logic

2. **Schedule Service**
   - [ ] Create `ScheduleService` with CRUD operations
   - [ ] Add `createSchedule(driverId, startDate, endDate)`
   - [ ] Add `getScheduleForDriver(driverId, dateRange)`
   - [ ] Add `getScheduleDayByDate(driverId, date)`
   - [ ] Enforce company isolation in queries

3. **Schedule API**
   - [ ] `POST /api/schedules` - create schedule for driver
   - [ ] `GET /api/schedules/driver/:id` - get driver schedule
   - [ ] `GET /api/schedules/day/:date` - get specific day
   - [ ] Add integration tests for schedule endpoints

#### Frontend Tasks
4. **Driver Schedule Management**
   - [ ] Add schedule state management (BLoC)
   - [ ] Create schedule service layer
   - [ ] Implement schedule API client
   - [ ] Add schedule creation/edit UI (if needed)

**Success Criteria**:
- Drivers have schedules with multiple days
- Schedules can be queried by date range
- All schedule operations respect company boundaries

---

### Phase 2: Dispatcher Assignment Interface (Week 3-4)
**Goal**: Enable manual ride assignment to driver schedules

#### Backend Tasks
1. **Assignment Logic in RideService**
   - [ ] Add `assignRideToDriver(rideId, driverId, scheduleDayId)`
   - [ ] Validate driver belongs to same company as ride
   - [ ] Validate scheduleDayId belongs to driver
   - [ ] Validate ride status is `Requested`
   - [ ] Update ride with `driverId` and `scheduleDayId`
   - [ ] Change ride status to `Assigned`

2. **Dispatcher Queries**
   - [ ] `GET /api/rides/pending` - rides with status `Requested`
   - [ ] `GET /api/drivers/schedules?date=YYYY-MM-DD` - all drivers' schedules for date
   - [ ] `GET /api/drivers/company/:companyId` - all drivers in company
   - [ ] Add conflict detection (overlapping ride times)

3. **Assignment API**
   - [ ] `POST /api/rides/:id/assign` - assign ride to driver + schedule day
   - [ ] Request: `{ driverId, scheduleDayId }`
   - [ ] Validate time conflicts
   - [ ] Return updated ride with assignment details

#### Frontend Tasks
4. **Dispatcher Dashboard UI**
   - [ ] **Pending Rides Queue** (left panel)
     - List all rides with `Requested` status
     - Show client name, pickup time, location, destination
     - Sort by pickup time / priority
     - Filter by urgency, location

   - [ ] **Driver Schedule Grid** (right panel)
     - Show all drivers with their schedules for selected date
     - Hourly timeline view (6 AM - 11 PM)
     - Color-coded availability (green/yellow/red)
     - Display existing rides in timeline slots

   - [ ] **Assignment Interaction**
     - Drag-and-drop from pending queue to driver timeline
     - Click-based assignment as alternative
     - Conflict detection with visual warnings
     - Confirmation dialog before assignment

   - [ ] **Real-time Updates**
     - Auto-refresh pending rides (polling every 30s)
     - Update driver schedules when rides assigned
     - Show assignment conflicts immediately

5. **Dispatcher BLoC State Management**
   - [ ] `DispatcherBloc` for pending rides and driver schedules
   - [ ] `AssignmentBloc` for drag-drop and assignment logic
   - [ ] Error handling for assignment conflicts

**Success Criteria**:
- Dispatcher can see all pending rides
- Dispatcher can view all driver schedules for a date
- Dispatcher can assign rides via drag-drop or click
- System prevents invalid assignments (wrong company, time conflicts)
- Ride status updates from `Requested` to `Assigned`

---

### Phase 3: Driver Workflow Integration (Week 5-6)
**Goal**: Connect driver schedule to actual ride execution

#### Backend Tasks
1. **Enhanced RideService**
   - [ ] Add validation: only assigned rides can be started
   - [ ] Add `getRidesForScheduleDay(scheduleDayId)` query
   - [ ] Add `getActiveRidesForDriver(driverId, date)` query
   - [ ] Update ride queries to join with schedule information

2. **Driver API Enhancements**
   - [ ] `GET /api/drivers/me/rides/today` - today's assigned rides only
   - [ ] `GET /api/drivers/me/rides/upcoming` - future assigned rides
   - [ ] `PUT /api/rides/:id/start` - start ride (validate status = Assigned)
   - [ ] `PUT /api/rides/:id/complete` - complete ride

#### Frontend Tasks
3. **Driver App Schedule Integration**
   - [ ] Update "Today's Rides" to fetch from schedule
   - [ ] Update calendar view to show assigned rides
   - [ ] Filter rides by status (active vs completed)
   - [ ] Link ride details to schedule context

4. **Ride Status Management**
   - [ ] Add "Start Ride" button (Assigned → InProgress)
   - [ ] Add "Complete Ride" button (InProgress → Completed)
   - [ ] Disable status changes if preconditions not met
   - [ ] Show validation errors to driver

**Success Criteria**:
- Drivers see only their assigned rides
- Drivers can start rides from Assigned status
- Drivers can complete rides from InProgress status
- Status transitions validated on backend and frontend

---

### Phase 4: Real-time Location & Tracking (Week 7-8)
**Goal**: Enable location sharing during active rides

#### Backend Tasks
1. **Location Tracking Infrastructure**
   - [ ] Add `current_locations` table (entity_type, entity_id, lat, lng, timestamp)
   - [ ] Create `LocationService` for storing/retrieving locations
   - [ ] Add TTL cleanup job (delete locations older than 24h)

2. **Location API**
   - [ ] `POST /api/location/update` - driver/client sends location
   - [ ] `GET /api/location/driver/:id` - get driver's current location
   - [ ] `GET /api/location/client/:id` - get client's current location
   - [ ] Add rate limiting (max 1 update per 10 seconds per entity)

3. **Ride-Location Integration**
   - [ ] Only allow location updates for active rides (InProgress status)
   - [ ] Return 403 if user not part of the ride
   - [ ] Add location to ride details response

#### Frontend Tasks
4. **Location Tracking UI**
   - [ ] Driver: Auto-send location every 30s during InProgress rides
   - [ ] Client: View driver location on map during InProgress rides
   - [ ] Update Mapbox markers in real-time
   - [ ] Handle permission requests and errors gracefully

5. **Map Integration Enhancement**
   - [ ] Optimize map performance (reduce update frequency if needed)
   - [ ] Add "Center on Driver" button for clients
   - [ ] Show last update timestamp
   - [ ] Offline fallback (show last known location)

**Success Criteria**:
- Drivers' locations are tracked during active rides
- Clients can see driver location on map
- Location updates happen smoothly without UI lag
- Locations are automatically cleaned up after 24h

---

### Phase 5: Company Isolation & Multi-tenancy (Week 9)
**Goal**: Ensure complete data isolation between companies

#### Backend Tasks
1. **Company Enforcement Audit**
   - [ ] Review all repository queries for company filtering
   - [ ] Add company checks in all service methods
   - [ ] Add integration tests for cross-company scenarios
   - [ ] Verify ride assignment prevents cross-company assignments

2. **Enhanced Security**
   - [ ] Add `companyId` to JWT claims
   - [ ] Enforce company in all authenticated endpoints
   - [ ] Add company-based authorization middleware
   - [ ] Audit logs for cross-company access attempts

3. **Company Management**
   - [ ] `GET /api/companies/:id` - company details
   - [ ] `GET /api/companies/:id/drivers` - company drivers
   - [ ] `GET /api/companies/:id/stats` - basic statistics

#### Frontend Tasks
4. **Company Context**
   - [ ] Store company ID in auth state
   - [ ] Add company name to user profile
   - [ ] Filter all lists by current company
   - [ ] Add company switcher (if user belongs to multiple - v2 feature)

**Success Criteria**:
- No cross-company data leaks in any API
- All queries automatically filtered by company
- Unauthorized access attempts logged
- Integration tests verify complete isolation

---

### Phase 6: Secretary Dashboard (Week 10)
**Goal**: Enable ride creation for clients

#### Backend Tasks
1. **Client Management**
   - [ ] `GET /api/clients` - list clients for company
   - [ ] `POST /api/clients` - create new client
   - [ ] `GET /api/clients/:id` - client details

2. **Ride Creation for Secretary**
   - [ ] `POST /api/rides` - create ride for client
   - [ ] Validate secretary belongs to same company as client
   - [ ] Set ride status to `Requested`
   - [ ] Set creator to secretary's Person ID

#### Frontend Tasks
3. **Secretary Dashboard UI**
   - [ ] **Create Ride Form**
     - Client selection dropdown
     - Pickup location input (with Google Places autocomplete)
     - Destination input
     - Pickup date/time picker
     - Notes field
     - Airport transfer toggle
     - Flight number (if airport)

   - [ ] **Client Management**
     - List company clients
     - Add new client
     - View client ride history

   - [ ] **Recent Rides**
     - Show recently created rides
     - Quick status overview

**Success Criteria**:
- Secretary can create rides for clients
- Newly created rides appear in dispatcher's pending queue
- Secretary sees confirmation after ride creation
- All rides respect company boundaries

---

### Phase 7: MVP Polish & Testing (Week 11-12)
**Goal**: Stabilize MVP for production use

#### Testing Tasks
1. **Integration Testing**
   - [ ] End-to-end scenario: Secretary creates → Dispatcher assigns → Driver executes
   - [ ] Test all role permissions and access controls
   - [ ] Test company isolation with multiple companies
   - [ ] Test error scenarios (conflicts, invalid data)

2. **Performance Testing**
   - [ ] Load test assignment endpoint with concurrent requests
   - [ ] Test location updates with multiple active rides
   - [ ] Optimize database queries (add indexes where needed)
   - [ ] Profile frontend performance

3. **User Acceptance Testing**
   - [ ] Test with real drivers on actual devices
   - [ ] Test dispatcher workflow on desktop/tablet
   - [ ] Gather feedback on UX issues
   - [ ] Fix critical bugs and usability problems

#### Polish Tasks
4. **Error Handling & UX**
   - [ ] Consistent error messages across all APIs
   - [ ] User-friendly error displays in Flutter
   - [ ] Loading states for all async operations
   - [ ] Empty state handling (no rides, no drivers, etc.)

5. **Documentation**
   - [ ] API documentation (OpenAPI/Swagger)
   - [ ] User manual for each role
   - [ ] Deployment guide
   - [ ] Database schema documentation

**Success Criteria**:
- All core workflows tested end-to-end
- No critical bugs or crashes
- Performance meets targets (<500ms API response, <2s page load)
- Ready for production deployment

---

## Post-MVP Roadmap

### v1.0 (Months 4-6): Operational Excellence
1. **Push Notifications**: Real-time ride updates via Firebase
2. **Advanced Reporting**: Driver statistics, revenue tracking
3. **Customer Segmentation**: VIP clients, corporate accounts
4. **Workforce Management**: Shift scheduling, breaks, overtime
5. **Emergency Procedures**: Driver reassignment, backup protocols
6. **Communication Systems**: In-app messaging, SMS notifications

### v2.0 (Months 7-12): Business Optimization
1. **AI-Powered Assignment**: Smart suggestions for ride assignment
2. **Fleet Management**: Vehicle tracking, maintenance scheduling
3. **Advanced Pricing**: Dynamic pricing, surge pricing, discounts
4. **Analytics Dashboard**: Business intelligence, forecasting
5. **Multi-language Support**: Internationalization (German, English, Ukrainian)
6. **Expense Tracking**: Fuel costs, vehicle expenses

### v3.0 (Year 2+): Scale & Growth
1. **Automated Dispatch**: Full automation with manual override
2. **Route Optimization**: AI-based route planning
3. **Payment Integration**: Stripe, PayPal, corporate billing
4. **Customer App**: Self-service ride booking
5. **API for Partners**: Integration with corporate systems
6. **Mobile Web**: PWA for clients without app

---

## Technology Stack Summary

### Backend
- **Language**: Scala 3.3.7
- **Framework**: ZIO 2.x (functional effects)
- **HTTP**: ZIO HTTP
- **Database**: PostgreSQL 14+
- **Migrations**: Flyway
- **Auth**: JWT with zio-json
- **Testing**: ZIO Test, Cucumber, ScalaTest
- **Build**: sbt 1.11.7

### Frontend
- **Framework**: Flutter 3.x
- **State Management**: flutter_bloc
- **Mapping**: Mapbox
- **HTTP**: dio
- **Local Storage**: shared_preferences
- **Navigation**: go_router

### Infrastructure
- **Deployment**: Docker + Docker Compose
- **CI/CD**: GitHub Actions
- **Monitoring**: Prometheus + Grafana (v1)
- **Logging**: Logback (backend), Sentry (frontend, v1)

---

## Risk Mitigation

### Technical Risks
1. **Real-time Performance**: Location updates may cause lag
   - **Mitigation**: Implement throttling, use WebSockets, optimize queries

2. **Concurrent Assignment**: Two dispatchers assign same ride
   - **Mitigation**: Optimistic locking, transaction isolation, UI feedback

3. **Data Consistency**: Schedule and ride state out of sync
   - **Mitigation**: Database constraints, transactional updates, validation

### Business Risks
1. **User Adoption**: Drivers resist using app
   - **Mitigation**: Simple UX, training sessions, gradual rollout

2. **Data Migration**: Existing Excel/paper schedules hard to import
   - **Mitigation**: Bulk import tools, manual entry assistance

3. **Scalability**: System slow with many concurrent users
   - **Mitigation**: Performance testing early, horizontal scaling design

---

## Success Metrics

### MVP Launch Criteria
- ✅ 3+ drivers using app daily
- ✅ 50+ rides created and assigned per week
- ✅ <5 minute average assignment time
- ✅ Zero cross-company data leaks
- ✅ 95%+ uptime during business hours
- ✅ All critical user flows tested

### Business KPIs (3 months post-launch)
- 85%+ driver adoption rate
- 90%+ on-time pickup performance
- 70%+ driver utilization during peak hours
- 5-10 minute average assignment time
- <1% error rate in ride creation/assignment

---

## Team & Timeline

### Recommended Team Structure
- **1 Backend Developer** (Scala/ZIO) - 30-40h/week
- **1 Frontend Developer** (Flutter) - 30-40h/week
- **1 Designer/UX** (part-time) - 10-15h/week
- **1 QA/Tester** (part-time) - 15-20h/week
- **1 Product Owner** - 10h/week coordination

### Estimated Timeline
- **MVP (Phases 1-7)**: 12 weeks (3 months)
- **v1.0**: +12 weeks (months 4-6)
- **v2.0**: +24 weeks (months 7-12)

### Critical Path
Week 1-2: Schedule Management → Week 3-4: Dispatcher UI → Week 5-6: Driver Integration → Week 7-8: Location Tracking → Week 9-12: Polish & Testing

---

## Next Immediate Steps

### This Week (Priority 1)
1. **Schedule Domain**: Implement `Schedule` and `ScheduleDay` entities
2. **Schedule Repository**: Add PostgreSQL implementation
3. **Flyway Migration**: Create schedule tables
4. **Unit Tests**: Test schedule creation and queries

### Next Week (Priority 2)
5. **Schedule Service**: Implement CRUD operations
6. **Schedule API**: Add REST endpoints
7. **Integration Tests**: Test schedule endpoints
8. **Frontend BLoC**: Add schedule state management

### Week 3 (Priority 3)
9. **Assignment Logic**: Implement ride-to-driver assignment
10. **Dispatcher Queries**: Add pending rides and driver schedules APIs
11. **Assignment API**: Create assign endpoint with validation
