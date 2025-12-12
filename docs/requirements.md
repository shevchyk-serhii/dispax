# Dispatcher - Business Requirements & Specifications

## Overview
A dispatcher usually owns the business. The dispatcher plans the schedule for the drivers.
His goal is to coordinate the rides among the drivers in order to achieve maximum profit for the business.

## Core Business Role

### Primary Responsibilities
- **Ride Distribution**: Efficiently distributes ride requests across available drivers and schedules
- **Manual Assignment (MVP)**: Reviews pending rides and assigns them to optimal driver schedules
- **Optimization Goals**: 
  - Maximize driver utilization
  - Minimize customer wait times
  - Reduce empty miles between rides
  - Optimize geographic efficiency

### Business Context
- In smaller companies, this role is typically fulfilled by the owner
- Acts as the central coordinator for all ride operations
- Responsible for business profitability through efficient resource allocation

## Current Workflow (MVP Implementation)

### Manual Dispatch Process
1. **Review Pending Requests**: Monitor rides with `Requested` status
2. **Driver Assessment**: Evaluate driver availability based on:
   - Current schedule and existing ride commitments
   - Geographic proximity to pickup location
   - Driver capacity and experience level
   - Time constraints and deadlines
   - Vehicle suitability for the ride type
3. **Assignment Decision**: Select optimal driver and assign ride
4. **Status Update**: Ride status changes from `Requested` to `Assigned`
5. **Schedule Integration**: Ride appears in driver's daily schedule

### Decision Factors
- **Geographic Efficiency**: Minimize travel time between rides
- **Time Management**: Ensure adequate buffer time between consecutive rides
- **Driver Workload**: Balance ride distribution across team
- **Client Priorities**: Handle VIP or urgent requests appropriately
- **Cost Optimization**: Reduce fuel costs and vehicle wear

## User Interface Requirements

### Dispatcher Dashboard Components

#### 1. Pending Rides Queue
- **List View**: All rides with `Requested` status
- **Ride Information**: 
  - Client name and contact information
  - Pickup location and destination
  - Requested pickup time
  - Special requirements (airport, wheelchair access, etc.)
  - Expected duration and distance
- **Priority Indicators**: Visual markers for urgent or high-priority rides
- **Sorting Options**: By pickup time, creation time, location proximity

#### 2. Driver Schedule Grid
- **Visual Schedule**: Grid layout showing all drivers and their daily schedules
- **Time Blocks**: Hourly view with existing ride assignments
- **Availability Indicators**: 
  - Green: Available
  - Yellow: Partially booked
  - Red: Fully booked
- **Driver Information**:
  - Name and contact details
  - Current location (if available)
  - Vehicle type and capacity
  - Special certifications (airport access, etc.)

#### 3. Assignment Interface
- **Drag-and-Drop**: Intuitive assignment by dragging rides to driver schedules
- **Click Assignment**: Alternative click-based assignment for precise scheduling
- **Conflict Detection**: Visual warnings for scheduling conflicts
- **Time Validation**: Automatic checks for realistic travel times between rides
- **Confirmation Dialogs**: Require confirmation for assignments with potential issues

### Advanced Features

#### Real-time Updates
- **Live Status**: Real-time updates of ride status changes
- **Driver Location**: Current driver positions on integrated map
- **Schedule Changes**: Immediate visibility of cancellations or modifications

#### Analytics Integration
- **Performance Metrics**: 
  - Average assignment time
  - Driver utilization rates
  - Customer satisfaction scores
  - Revenue per driver/per day
- **Historical Data**: Past performance to inform assignment decisions

## Technical Specifications

### API Requirements

#### Dispatcher Endpoints
```
GET  /api/rides/pending        // Rides awaiting assignment
GET  /api/drivers/schedules    // All driver schedules for date range
POST /api/rides/assign         // Assign ride to specific driver
GET  /api/dashboard/summary    // Real-time dashboard data
GET  /api/analytics/dispatcher // Performance analytics
```

#### Data Requirements
- **Real-time Updates**: WebSocket or Server-Sent Events for live data
- **Caching Strategy**: Cache driver schedules for performance
- **Conflict Resolution**: Handle concurrent assignment attempts
- **Audit Trail**: Log all assignment decisions for analysis

### Interface Design Standards

#### Layout Principles
- **Split View**: Pending rides on left, driver schedules on right
- **Responsive Design**: Adapt to different screen sizes
- **Keyboard Shortcuts**: Power user features for efficient operation
- **Color Coding**: Consistent visual language for status and priorities

#### User Experience
- **Quick Assignment**: Minimize clicks for common operations
- **Undo Functionality**: Allow reversal of recent assignments
- **Batch Operations**: Handle multiple rides simultaneously
- **Search and Filter**: Find specific rides or drivers quickly

## Business Rules & Constraints

### Assignment Rules
1. **Company Isolation**: Drivers can only be assigned rides within their own company
2. **Status Validation**: Only rides with `Requested` status can be assigned
3. **Schedule Integrity**: Assignments must reference a valid `ScheduleDay`
4. **Time Validation**: Ensure realistic scheduling with adequate travel time
5. **Driver Capacity**: Respect maximum rides per driver per day

### Optimization Guidelines
- **Geographic Clustering**: Group rides by area when possible
- **Time Efficiency**: Minimize gaps in driver schedules
- **Client Satisfaction**: Prioritize on-time performance over maximum utilization
- **Flexibility**: Maintain buffer time for unexpected delays

## Future Enhancements (Phase 2)

### AI-Powered Assignment
- **Smart Suggestions**: System recommends optimal driver assignments
- **Historical Learning**: Use past data to improve assignment quality
- **Automatic Assignment**: Fully automated dispatch with manual override capability
- **Predictive Analytics**: Forecast demand and suggest proactive scheduling

### Advanced Features
- **Route Optimization**: Consider traffic patterns and road conditions
- **Multi-criteria Decision**: Balance multiple factors (cost, time, satisfaction)
- **What-if Analysis**: Test different assignment scenarios
- **Mobile Interface**: Tablet-optimized interface for field operations

## Success Metrics

### Key Performance Indicators
- **Assignment Speed**: Average time from ride request to assignment
- **Utilization Rate**: Percentage of driver time with active rides
- **Customer Wait Time**: Time from request to pickup
- **Revenue Efficiency**: Revenue per mile driven
- **Driver Satisfaction**: Balance of workload across team

### Target Benchmarks (MVP)
- Assignment within 5 minutes of ride request
- 85% driver utilization during peak hours
- 95% on-time pickup performance
- Maximum 15-minute customer wait time
- Equal workload distribution (±10% variance between drivers)

## Business Requirements Clarifications

### 1. Company Structure & Scale
**Q: How many drivers typically work in one company?**
- Important for UI design: 3-5 drivers = single screen view, 20-50 drivers = need filters and pagination
- _Answer: [TO BE FILLED]_

### 2. Dispatcher Role & Permissions
**Q: Can dispatcher only assign rides or also create them? Can they change ride status?**
- Important for feature set: assignment-only vs full ride management capabilities
- _Answer: Can create rides independently_

### 3. Business Ownership
**Q: Is dispatcher always the business owner or can be an employee?**
- Important for access levels: financial reports, administrative functions, system settings
- _Answer: Need to support both owner and employee roles_

### 4. Order Sources
**Q: Where do ride requests come from? Only through secretary or other channels?**
- Important for data sources and order prioritization systems
- _Answer: Usually through secretary, but clients can create rides themselves. Drivers can also create rides_

### 5. Order Types & Urgency
**Q: What types of orders exist - scheduled or urgent "now" requests? How to prioritize them?**
- Important for assignment algorithm and queue interface design
- _Answer: Various types_

### 6. Airport Operations
**Q: Are airport rides specific work type? Special license/permit needed for airport work?**
- Important for driver filtering and assignment rules
- _Answer: We don't handle permits, assume drivers handle this themselves_

### 7. Assignment Priorities
**Q: What's more important - minimize client wait time or maximize driver utilization?**
- Important for assignment algorithm priorities
- _Answer: Client should not wait. We wait for client, these are business clients, time is everything for them_

### 8. Geographic Coverage
**Q: Do you work within one city or cover large region?**
- Important for trip time calculations and scheduling complexity
- _Answer: MVP for Munich and suburbs, quite large distances, up to 100km one way_

### 9. Pricing Model
**Q: Is ride cost considered when assigning driver? Fixed tariffs or distance/time-based?**
- Important for assignment logic and financial tracking
- _Answer: Often have agreements with companies and price is fixed_

### 10. Reporting Requirements
**Q: What reporting does dispatcher need? Financial summary, driver statistics, assignment efficiency?**
- Important for dashboard design and data collection requirements
- _Answer: Number of rides, earnings, distance driven_

### 11. External Integrations
**Q: Need integration with external systems - banks, tax services, GPS trackers?**
- Important for system architecture and future roadmap
- _Answer: In future can add expense tracking functionality (e.g., fuel costs)_

### 12. Time Calculation
**Q: Can we use Google API for trip time calculations?**
- Important for scheduling accuracy and assignment validation
- _Answer: Yes, can calculate approximate time through Google_

## Implementation Phases - Additional Considerations

### Phase Distribution Strategy
We will implement in phases: **MVP → v1 → v2**. Critical questions need to be assigned to appropriate phases.

### Additional Business Requirements by Category

#### Driver Operations & Workforce Management
**Q: Do drivers work fixed shifts or flexible schedules? How to handle breaks and maximum working hours?**
- Important for: Legal compliance, schedule management, driver welfare
- Suggested Phase: _v1 (workforce optimization)_

**Q: Night shifts - different rates? Overtime policies in German labor law?**
- Important for: Cost calculations, legal compliance
- Suggested Phase: _v2 (advanced pricing)_

#### Vehicle & Resource Management  
**Q: One driver = one vehicle or vehicle rotation possible?**
- Important for: Assignment logic, resource optimization
- Suggested Phase: _MVP (basic assignment rules)_

**Q: Different vehicle types (sedan, minivan, luxury) for different client segments?**
- Important for: Service differentiation, premium offerings
- Suggested Phase: _v1 (service tiers)_

**Q: Vehicle maintenance scheduling - how to exclude vehicles from service?**
- Important for: Service continuity, operational planning
- Suggested Phase: _v2 (fleet management)_

#### Emergency & Business Continuity
**Q: Driver illness/vehicle breakdown during shift - reassignment procedures?**
- Important for: Risk management, client satisfaction
- Suggested Phase: _v1 (operational reliability)_

**Q: Backup drivers on standby? Emergency contact protocols?**
- Important for: Service guarantee, premium service levels
- Suggested Phase: _v2 (service excellence)_

#### Client Relationship Management
**Q: VIP clients with preferred drivers? Corporate account special requirements?**
- Important for: Customer retention, premium pricing
- Suggested Phase: _v1 (customer segmentation)_

**Q: Client/driver blacklist for conflict avoidance?**
- Important for: Service quality, conflict resolution
- Suggested Phase: _v2 (relationship management)_

#### Financial Operations & Compliance
**Q: Fuel costs - company expense or driver responsibility? Commission structure?**
- Important for: Cost structure, profit margins
- Suggested Phase: _MVP (basic financials)_

**Q: German tax compliance, insurance liability, legal documentation?**
- Important for: Legal operation, risk management  
- Suggested Phase: _v1 (compliance framework)_

#### Operational Procedures
**Q: Client late 30+ minutes - waiting fees? Cancellation policies and penalties?**
- Important for: Revenue optimization, fairness policies
- Suggested Phase: _v1 (operational procedures)_

**Q: Multi-stop rides, luggage requirements, special equipment needs?**
- Important for: Service expansion, complex bookings
- Suggested Phase: _v2 (advanced services)_

#### Communication & User Experience
**Q: Real-time notifications to drivers? Multi-language interface support?**
- Important for: User experience, market expansion
- Suggested Phase: _v1 (communication systems)_

**Q: Customer communication preferences (SMS, email, app)? Feedback systems?**
- Important for: Customer satisfaction, service improvement
- Suggested Phase: _v2 (customer experience)_

### Confirmed MVP Scope

#### Core MVP Features (Confirmed Requirements)
1. **Ride Creation**: Secretary, dispatcher, driver, or client can create rides
2. **Manual Assignment**: Dispatcher manually assigns rides to drivers  
3. **Driver Data Display**: Complete ride information visible to assigned drivers
4. **Airport Location Exchange**: Critical feature for driver-passenger coordination at airports

#### MVP Focus: Essential Operations Only
- **Ride Management**: Create, assign, track ride status (Requested → Assigned → InProgress → Completed)
- **Manual Dispatch Interface**: Dispatcher dashboard for ride assignment
- **Driver Information Display**: All necessary ride details for drivers
- **Location Sharing for Airport Pickups**: Real-time location exchange between driver and passenger
- **Basic User Roles**: Driver, Client, Secretary, Dispatcher with appropriate permissions
- **Company Isolation**: Multi-tenant system with company-based data separation

#### Critical MVP Requirements Based on Business Needs

##### Airport Operations (High Priority)
- **Location Sharing**: Driver can share location with client, client can share with driver
- **Real-time Coordination**: Essential for airport pickups where precise meeting coordination is critical
- **Flight Integration**: Basic flight information display for timing
- **Airport Entry Timing**: Visual countdown for optimal airport entry to minimize parking costs

##### Assignment Interface (Core Function)
- **Pending Rides Queue**: Display all unassigned rides (Requested status)
- **Driver Schedule Overview**: Visual representation of driver availability
- **Drag-and-Drop Assignment**: Intuitive assignment interface for dispatcher
- **Conflict Detection**: Basic validation for scheduling conflicts
- **Time Estimation**: Google API integration for travel time calculations

##### Data Display for Drivers (Essential for Operations)
- **Today's Rides**: Current day active rides with status tracking
- **Ride Details**: Complete information - client, pickup/destination, timing, special requirements
- **Status Management**: Ability to update ride status (start, complete, etc.)
- **Client Contact**: Direct access to client contact information
- **Navigation Integration**: Launch external navigation apps for route guidance

#### MVP Exclusions (Deferred to v1/v2)
- Advanced workforce management and shift scheduling
- Vehicle type differentiation and fleet management
- Emergency reassignment procedures
- VIP client preferences and corporate account management
- Advanced financial tracking and expense management
- Multi-language support and localization
- Push notification systems
- Advanced analytics and reporting
- Automated assignment algorithms

#### v1 Focus: Operational Excellence  
- Advanced workforce management and compliance
- Customer segmentation and service tiers
- Emergency procedures and backup systems
- Communication and notification systems
- Advanced financial operations

#### v2 Focus: Business Optimization
- Fleet management and maintenance scheduling
- Advanced pricing and service differentiation
- Customer relationship management
- Analytics and business intelligence
- AI-powered assignment suggestions