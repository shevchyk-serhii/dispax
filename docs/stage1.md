# Taxi Ride Planning Application

## Overview
A comprehensive ride planning application designed for taxi companies to manage orders, rides, and schedules efficiently.

## Features

### Core Operations
- **Orders Management**: Complete CRUD operations for ride orders
- **Rides Management**: Complete CRUD operations for active rides
- **Schedule Management**: Complete CRUD operations for taxi company schedules
- **Notification System**: Real-time notifications for drivers, clients, and secretaries
- **Invoice Generation**: Automated billing and payment processing
- **Analytics Dashboard**: Statistics and performance analytics

### Mobile Application for Clients
The client mobile app provides:
- **Ride Overview**: Clients can view their current and upcoming rides
- **Driver Information**: Access to driver details and contact information
- **Real-time Tracking**: Driver's current location and estimated pickup time
- **Driver Profile**: Driver's photo (if permission granted)
- **Pricing Information**: Trip cost (if disclosure enabled)
- **Vehicle Details**: Car model and vehicle information
- **Journey Estimates**: Average travel time to destination
- **Arrival Predictions**: Approximate time of arrival
- **Flight Integration**: Planned aircraft departure times (for airport/railway station trips)

### Mobile Application for Drivers
The driver mobile app includes:
- **Calendar-Based Schedule View**: Interactive calendar interface for viewing ride schedule
  - **Calendar Navigation**: Swipe between days/weeks/months to see future and past rides
  - **Day View**: Detailed timeline showing all rides for selected date
  - **Week View**: Overview of 7-day schedule with ride density indicators
  - **Month View**: Monthly calendar with ride count badges per day
  - **Today Highlight**: Quick access to current day's schedule
- **Ride Management**: Complete schedule of assigned rides with status tracking
- **Client Information**: Passenger details and contact information  
- **Flight Schedules**: Departure times for airport pickups
- **Weather Updates**: Current weather conditions along the route (when available)
- **Navigation Support**: Estimated arrival times and route optimization

### Web Application for Secretaries
The secretary web portal features:
- **Order Management**: Create and manage ride orders
- **Airport Operations**: Specialized tools for airport client meetings
- **Location Sharing**: 
  - Share driver location with clients
  - Share client location with drivers
- **Airport Timing Optimization**: Calculate optimal airport entry times to minimize waiting periods and reduce airport fees

## User Roles

### Driver
- Responsible for transporting clients to their destinations
- Manages ride schedules and client interactions

### Taxi Dispatcher
- **Primary Role**: Efficiently distributes ride requests across available drivers and schedules
- **Manual Assignment (MVP)**: Reviews pending rides and assigns them to optimal driver schedules
- **Optimization Goals**: Maximize driver utilization, minimize customer wait times, reduce empty miles
- **Future Enhancement**: AI-powered automatic assignment based on historical data and real-time conditions
- In smaller companies, this role is typically fulfilled by the owner

### Client
- The passenger being transported
- Receives ride notifications and tracking information

### Secretary
- Primary contact for booking rides and managing client accounts
- Handles payment processing for corporate clients

## Workflow

### Current Flow (MVP)
1. **Ride Request**: Secretary creates a ride request in the system (status: `Requested`)
2. **Manual Dispatch**: Dispatcher reviews pending requests and manually assigns rides to drivers based on:
   - Driver availability and schedule
   - Geographic proximity
   - Driver capacity and experience
   - Time constraints
3. **Ride Assignment**: Ride status changes to `Assigned` and appears in driver's schedule
4. **Client Notification**: Client receives notification with ride details and driver information
5. **Service Start**: Driver starts the pickup process (status: `InProgress`)
6. **Service Delivery**: Driver picks up the client and transports them to the destination
7. **Completion**: Ride is marked as completed (status: `Completed`)
8. **Billing Process**: System generates invoice and processes payment through the company

### Future Enhanced Flow (Phase 2)
- **Smart Assignment**: System suggests optimal driver assignments based on:
  - Historical ride duration data
  - Traffic patterns
  - Driver performance metrics
  - Real-time location data
- **Automatic Assignment**: Fully automated dispatch with manual override capability


## Data Model

### Core Entities

#### Person
- Base entity that can have different roles: Driver, Secretary, or Client
- Serves as the foundation for user management and authentication

#### Driver
- Extends Person entity
- Can create and manage personal schedules
- Responsible for ride execution
- Works exclusively for one company (cannot be employed by multiple companies simultaneously)

#### Schedule
- Contains multiple ScheduleDay entities
- Represents a driver's availability and planned rides
- Allows for efficient resource planning

#### ScheduleDay
- Represents a single day within a schedule
- Can contain one or more rides per day
- Enables detailed daily planning

#### Ride
- Core business entity representing a trip request and execution
- Has a creator (can be driver, taxi dispatcher, or secretary)  
- Has a client who will be transported
- May be assigned to a specific driver (optional until assigned)
- Contains pickup/destination information and timing
- Tracks ride status through its lifecycle
- Links to a specific ScheduleDay when assigned to a driver

#### RideStatus (Enum)
- **Requested**: Ride created by secretary, awaiting driver assignment
- **Assigned**: Driver has accepted the ride, added to their schedule
- **InProgress**: Driver has started pickup/transport process  
- **Completed**: Ride successfully finished
- **Cancelled**: Ride cancelled before or during execution

#### Company
- Organizational entity that manages the entire operation
- Can employ multiple drivers
- Must have one or more dispatchers for operational oversight

### Entity Relationships
- **Person** → **Driver/Secretary/Client** (inheritance/role-based)
- **Driver** → **Company** (many-to-one, required - each driver belongs to exactly one company)
- **Secretary** → **Company** (many-to-one, required - each secretary works for exactly one company)
- **Driver** → **Schedule** (one-to-many)
- **Schedule** → **ScheduleDay** (one-to-many)  
- **Ride** → **ScheduleDay** (many-to-one, optional until assigned)
- **Ride** → **Driver** (many-to-one, optional until assigned)
- **Ride** → **Client** (many-to-one, required)
- **Ride** → **Creator** (many-to-one, required - Person who created the ride)
- **Ride** → **Company** (many-to-one, required - ride belongs to company that created it)
- **Company** → **Dispatcher** (one-to-many)

### Ride Lifecycle
```
Requested → Assigned → InProgress → Completed
    ↓           ↓           ↓
Cancelled   Cancelled   Cancelled
```

### Key Business Rules
1. **Driver Employment**: Each driver works exclusively for one company (cannot have multiple employers)
2. **Ride Assignment**: Only rides with status `Requested` can be assigned to drivers
3. **Cross-Company Rides**: Drivers can only be assigned rides within their own company
4. **Ride Progression**: Only assigned rides (`Assigned` status) can be started (`InProgress`)
5. **Cancellation**: Rides can be cancelled at any stage before `Completed`
6. **Schedule Integration**: When a ride is assigned to a driver, it must reference a `ScheduleDay`
7. **Schedule Ownership**: A `ScheduleDay` can contain multiple rides but belongs to only one driver

## MVP Scope Definition

### Core MVP Features (Must Have)

#### 1. User Management
- **Person/Driver/Secretary/Client** entities
- Basic authentication (login/logout)
- Role-based access (no complex permissions yet)

#### 2. Ride Management
- **Ride CRUD** with 5 statuses (Requested → Assigned → InProgress → Completed → Cancelled)
- Secretary creates rides
- Driver accepts/rejects ride requests
- Basic ride assignment to ScheduleDay

#### 3. Schedule Management
- **Driver Schedule** creation
- **ScheduleDay** with date and basic availability
- Link rides to specific days

#### 4. Company Structure
- **Company** entity
- **Driver belongs to one Company**
- Ride isolation per company

#### 5. Basic Mobile Apps
- **Driver app**: View assigned rides, change status
- **Client app**: View their rides and status
- **Secretary web**: Create rides for clients
- **Dispatcher web**: Manual ride assignment interface with driver schedule overview

### MVP Exclusions (Phase 2)

#### Features NOT in MVP:
- ❌ Continuous real-time location tracking (only on-demand)
- ❌ Flight API integration  
- ❌ Weather integration
- ❌ Advanced pricing/billing
- ❌ Invoice generation
- ❌ Push notifications (just basic status updates)
- ❌ Route optimization
- ❌ Vehicle management
- ❌ Advanced analytics
- ❌ Multi-language support
- ❌ Location history/playback

### MVP Data Model (Simplified)

#### Core Entities (Simplified for MVP):
```
Person (id, name, email, role, companyId?, licenseNumber?, phone?)
  role: Driver | Secretary | Client

Company (id, name)

Schedule (id, driverId)
└── ScheduleDay (id, scheduleId, date)

Ride (id, clientId, creatorId, driverId?, scheduleDayId?, 
      from, to, pickupDateTime, status)

Location (address) // simplified - no coordinates

CurrentLocation (entityType, entityId, latitude, longitude, 
                accuracy, timestamp, speed?) // for real-time tracking

PersonRole (enum): Driver, Secretary, Client, Dispatcher
```

#### Field Usage by Role:
- **Driver**: companyId (required), licenseNumber (optional)
- **Secretary**: companyId (required)  
- **Dispatcher**: companyId (required)
- **Client**: phone (optional)
- **All**: id, name, email, role (required)

### MVP Success Criteria
1. ✅ Secretary can create ride requests
2. ✅ Dispatcher can manually assign rides to drivers  
3. ✅ Driver can see assigned rides and update status
4. ✅ Client can see their ride status  
5. ✅ Ride progresses through all statuses
6. ✅ Multiple companies work in isolation
7. ✅ Basic mobile apps functional

### Key MVP Interfaces
- **Dispatcher Dashboard**: 
  - List of pending rides (`Requested` status)
  - Grid view of driver schedules 
  - Drag-and-drop assignment interface
  - Basic ride details (pickup time, location, client)

## Location Tracking Strategy

### MVP Approach (Simplified)
- **Storage**: Single table in main database with TTL cleanup
- **Frequency**: Location updates only when needed:
  - Driver starts ride → send location
  - Client requests driver location → get latest
  - Ride completed → stop tracking
- **Data Retention**: Keep only current location (last 24 hours max)

### Implementation Details
```sql
CREATE TABLE current_locations (
  entity_type VARCHAR(10),  -- 'driver' | 'client'
  entity_id BIGINT,
  latitude DECIMAL(10,8),
  longitude DECIMAL(11,8),
  accuracy FLOAT,
  updated_at TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (entity_type, entity_id)
);

-- Auto-cleanup old locations
CREATE INDEX idx_updated_at ON current_locations(updated_at);
-- Scheduled job: DELETE FROM current_locations WHERE updated_at < NOW() - INTERVAL '24 hours';
```

### API Endpoints (MVP)
```
POST /api/location/update     -- Driver/Client sends location
GET  /api/location/driver/:id -- Client gets driver location  
GET  /api/location/client/:id -- Driver gets client location (for pickup)
```

### Future Enhancements (Phase 2)
- **Redis caching** for high-frequency updates
- **WebSocket streaming** for real-time updates
- **Location history** in time-series database
- **Geofencing** for automatic status updates

## Flutter Application Architecture

### Single Application Approach
For MVP simplicity, we use one Flutter application with role-based authentication and navigation.

### Navigation Structure
```
LoginScreen
    ↓
DashboardScreen (displays interface based on user role)
    ├── Driver Dashboard
    │   ├── Calendar Schedule (interactive calendar with ride navigation)
    │   │   ├── Month View (calendar grid with ride indicators)
    │   │   ├── Week View (7-day timeline overview)
    │   │   └── Day View (detailed daily schedule)
    │   ├── Today's Rides (quick access to current day)
    │   ├── Upcoming Rides (next 7 days overview)
    │   └── Profile
    ├── Client Dashboard  
    │   ├── MyRides (current and past rides)
    │   ├── RideStatus (track current ride)
    │   └── Profile
    ├── Secretary Dashboard
    │   ├── CreateRides (for clients)
    │   ├── ManageClients
    │   └── Reports
    └── Dispatcher Dashboard
        ├── PendingRides (status: Requested)
        ├── DriverSchedules (grid view)
        └── AssignRides (drag-and-drop interface)
```

### Key Components
- **AuthService** - authentication and role management
- **RoleBasedRouter** - navigation based on user role
- **RoleBasedWidget** - conditional UI elements by role
- **PersonModel** - with role enum (Driver/Client/Secretary/Dispatcher)

### File Structure
```
lib/
├── auth/
│   ├── login_screen.dart
│   ├── auth_service.dart
│   └── auth_state.dart
├── dashboard/
│   ├── driver/
│   │   ├── driver_dashboard.dart
│   │   ├── calendar/
│   │   │   ├── calendar_schedule_screen.dart
│   │   │   ├── month_view_widget.dart
│   │   │   ├── week_view_widget.dart
│   │   │   └── day_view_widget.dart
│   │   ├── today_rides_screen.dart
│   │   └── upcoming_rides_screen.dart
│   ├── client/
│   │   ├── client_dashboard.dart
│   │   ├── my_rides_screen.dart
│   │   └── ride_status_screen.dart
│   ├── secretary/
│   │   ├── secretary_dashboard.dart
│   │   ├── create_ride_screen.dart
│   │   └── manage_clients_screen.dart
│   └── dispatcher/
│       ├── dispatcher_dashboard.dart
│       ├── pending_rides_screen.dart
│       └── assign_rides_screen.dart
├── shared/ 
│   ├── widgets/
│   ├── screens/ (common screens like profile)
│   └── utils/
├── models/ (shared data models)
├── services/ (API services)
└── main.dart
```

### Role-Based Features Matrix
| Feature | Driver | Client | Secretary | Dispatcher |
|---------|--------|--------|-----------|------------|
| View Rides | Assigned only | Own only | All company | All company |
| Create Rides | No | No | Yes | No |
| Assign Rides | No | No | No | Yes |
| Update Ride Status | Yes | No | No | Yes |
| Manage Schedule | Own only | No | No | View all |

### Development Guidelines
- **Logging Language**: All logging, debugging messages, and system outputs must be in English
- **User Interface**: User-facing text should be in English
- **Code Comments**: When needed, comments should be in English
- **Variable/Function Names**: Always in English following standard conventions
- **Naming Conventions**: 
  - Do not use underscores in public class names and method names (use camelCase/PascalCase)
  - Private methods in Dart can use underscore prefix (standard Dart convention)

## Driver Calendar Interface Design

### Overview
The driver interface centers around a calendar-based schedule view that provides intuitive navigation through past, present, and future rides. This design allows drivers to efficiently plan their time and understand their workload distribution.

### Calendar Navigation Features

#### 1. Month View
- **Calendar Grid**: Standard monthly calendar layout with clickable dates
- **Ride Indicators**: 
  - Color-coded dots showing ride count per day
  - Green: 1-2 rides, Yellow: 3-4 rides, Red: 5+ rides
  - Gray: No rides scheduled
- **Quick Navigation**: 
  - Swipe left/right to navigate between months
  - Tap month/year header for date picker
- **Today Highlight**: Current date prominently highlighted
- **Weekend Styling**: Weekends visually distinguished

#### 2. Week View  
- **7-Day Timeline**: Horizontal week display with time slots
- **Ride Blocks**: Visual ride blocks showing duration and overlap
- **Time Slots**: 30-minute intervals from 6 AM to 11 PM
- **Scroll Navigation**: Horizontal scroll to previous/next weeks
- **Compact Info**: Ride destination and client name in blocks

#### 3. Day View
- **Detailed Timeline**: Hourly breakdown of selected day
- **Full Ride Details**: Complete ride information cards
- **Status Indicators**: Visual status of each ride (Assigned/InProgress/Completed)
- **Action Buttons**: Start ride, mark completed, contact client
- **Travel Time**: Estimated time between consecutive rides
- **Buffer Time**: Visual indicators of free time between rides

### Interface Components

#### Calendar Widget Features
```dart
// Key functionality
- Date selection with ride data loading
- Multi-view support (month/week/day)
- Smooth animations between views
- Ride count badges and color coding
- Touch gestures for navigation
- Pull-to-refresh for data updates
```

#### Ride Information Display
- **Ride Cards**: Clean card design with essential information
- **Priority Indicators**: Urgent rides highlighted (airport runs, etc.)  
- **Client Contact**: Quick access to call/message client
- **Navigation Integration**: Launch maps for route guidance
- **Status Management**: Easy status updates with confirmation

#### Navigation Features
- **Bottom Tab Bar**: Easy switching between Today/Calendar/Upcoming
- **FAB (Floating Action Button)**: Quick access to "Today" from any view
- **Header Controls**: Month/week navigation arrows and date picker
- **Search Functionality**: Find rides by client name or destination

### User Experience Flow

#### Daily Workflow
1. **Morning Check**: Open app to Today view for current schedule
2. **Day Planning**: Switch to Day view to see detailed timeline
3. **Week Planning**: Use Week view to understand upcoming workload
4. **Monthly Overview**: Month view for longer-term planning

#### Navigation Patterns
- **Tap to Drill Down**: Month → Week → Day → Ride Details
- **Swipe Navigation**: Quick horizontal navigation within same view level
- **Back Navigation**: Breadcrumb-style navigation to previous view
- **Quick Actions**: Long-press for context menus (call client, start navigation)

### Technical Implementation

#### Calendar Library
- **table_calendar**: Flutter package for calendar widget
- **Custom Styling**: Company branding and ride indicators
- **Performance**: Efficient loading of ride data per month/week

#### Data Management  
- **Caching**: Cache ride data for current month ± 1 month
- **Lazy Loading**: Load ride details on-demand when viewing day
- **Real-time Updates**: WebSocket updates for ride status changes
- **Offline Support**: Cache essential data for offline viewing

#### Responsive Design
- **Phone Optimization**: Optimized for mobile screens
- **Tablet Support**: Extended views with side panels
- **Orientation**: Both portrait and landscape support
- **Accessibility**: Screen reader support and large font options

### Future Enhancements
- **Filter Options**: Filter by ride status, client type, destination area
- **Statistics Integration**: Daily/weekly earnings and ride statistics  
- **Route Optimization**: Suggest optimal route order for multiple rides
- **Weather Integration**: Weather forecast overlay on calendar
- **Sync Integration**: Calendar app synchronization
- **Voice Commands**: Voice-activated navigation and status updates

### MVP Timeline Estimate
- **Backend**: 2-3 weeks
- **Flutter App**: 3-4 weeks (additional week for calendar interface)
- **Integration & Testing**: 1-2 weeks
- **Total**: ~7-8 weeks for working MVP with calendar interface