# API Endpoints

All endpoints return JSON. Authenticated endpoints require `Authorization: Bearer <JWT>` header.

## Health

| Method | Path      | Auth | Description  |
|--------|-----------|------|--------------|
| GET    | `/health` | No   | Health check |

## Auth

| Method | Path              | Auth | Description                                                |
|--------|-------------------|------|------------------------------------------------------------|
| POST   | `/api/auth/login` | No   | Login (email + password), returns JWT token. Rate limited. |

## Users

| Method | Path                           | Auth | Roles                        | Description                                     |
|--------|--------------------------------|------|------------------------------|-------------------------------------------------|
| GET    | `/api/users`                   | Yes  | DISPATCHER, ADMIN            | List all users for company                      |
| GET    | `/api/users/{id}`              | Yes  | DISPATCHER, ADMIN, or owner  | Get user details                                |
| POST   | `/api/users`                   | Yes  | DISPATCHER, ADMIN            | Create new user                                 |
| PUT    | `/api/users/{id}`              | Yes  | DISPATCHER, ADMIN, or self   | Update user details                             |
| DELETE | `/api/users/{id}`              | Yes  | DISPATCHER, ADMIN            | Deactivate user                                 |
| PUT    | `/api/users/{id}/role`         | Yes  | DISPATCHER                   | Change user role                                |
| PUT    | `/api/users/{id}/status`       | Yes  | DISPATCHER                   | Activate/suspend/deactivate user                |
| GET    | `/api/users/drivers`           | Yes  | DISPATCHER, ADMIN            | List company drivers                            |
| GET    | `/api/users/clients`           | Yes  | DISPATCHER, ADMIN, SECRETARY | List company clients                            |
| GET    | `/api/users/stats`             | Yes  | DISPATCHER                   | User counts by role and status                  |
| PUT    | `/api/users/change-password`   | Yes  | Any                          | Change own password. Rate limited.              |
| POST   | `/api/users/fcm-token`         | Yes  | Any                          | Register FCM push notification token            |
| DELETE | `/api/users/fcm-token/{token}` | Yes  | Any                          | Unregister FCM token                            |
| PUT    | `/api/users/reminder-minutes`  | Yes  | Any                          | Save driver's ride reminder lead time (minutes) |

## Rides

> For end-to-end ride flows (create / cancel / modify) — status machine, role matrices,
> validation, side-effects, failure modes and test-case catalogue — see
> [`ride-flows.md`](ride-flows.md).

| Method | Path                                  | Auth | Roles                                 | Description                                      |
|--------|---------------------------------------|------|---------------------------------------|--------------------------------------------------|
| POST   | `/api/rides`                          | Yes  | DISPATCHER, SECRETARY, CLIENT, DRIVER | Create ride                                      |
| GET    | `/api/rides`                          | Yes  | Any                                   | Get rides for company (paginated: offset, limit) |
| GET    | `/api/rides/pending`                  | Yes  | DISPATCHER                            | List pending (Requested) rides                   |
| GET    | `/api/rides/{rideId}`                 | Yes  | DRIVER, CLIENT, DISPATCHER, SECRETARY | Get ride details                                 |
| GET    | `/api/rides/driver/{driverId}`        | Yes  | Driver owner, DISPATCHER              | Get driver's rides                               |
| GET    | `/api/rides/client/{clientId}`        | Yes  | DISPATCHER, SECRETARY                 | Get client's rides                               |
| PUT    | `/api/rides/{rideId}`                 | Yes  | DRIVER, DISPATCHER, SECRETARY         | Update ride details                              |
| PUT    | `/api/rides/{rideId}/status`          | Yes  | DRIVER, DISPATCHER                    | Update ride status                               |
| PUT    | `/api/rides/{rideId}/assign-driver`   | Yes  | DISPATCHER                            | Assign driver to ride                            |
| PUT    | `/api/rides/{rideId}/reassign-driver` | Yes  | DISPATCHER                            | Reassign driver                                  |
| PUT    | `/api/rides/{rideId}/cancel`          | Yes  | DRIVER, DISPATCHER, CLIENT            | Cancel ride with reason                          |
| PUT    | `/api/rides/{rideId}/payment`         | Yes  | DISPATCHER                            | Mark payment                                     |
| GET    | `/api/rides/unpaid`                   | Yes  | DISPATCHER                            | List unpaid completed rides                      |
| POST   | `/api/rides/{rideId}/airport-timing`  | Yes  | CLIENT, DRIVER, DISPATCHER            | Calculate airport timing                         |

## Ride Location

| Method | Path                                  | Auth | Roles                      | Description            |
|--------|---------------------------------------|------|----------------------------|------------------------|
| POST   | `/api/rides/{rideId}/client-location` | Yes  | CLIENT                     | Update client location |
| GET    | `/api/rides/{rideId}/locations`       | Yes  | CLIENT, DRIVER, DISPATCHER | Get location history   |

## Chat

| Method | Path                       | Auth | Roles                      | Description       |
|--------|----------------------------|------|----------------------------|-------------------|
| POST   | `/api/rides/{rideId}/chat` | Yes  | CLIENT, DRIVER             | Send chat message |
| GET    | `/api/rides/{rideId}/chat` | Yes  | CLIENT, DRIVER, DISPATCHER | Get chat messages |

## Ride Ratings

| Method | Path                         | Auth | Roles                      | Description               |
|--------|------------------------------|------|----------------------------|---------------------------|
| POST   | `/api/rides/{rideId}/rate`   | Yes  | CLIENT                     | Rate completed ride (1-5) |
| GET    | `/api/rides/{rideId}/rating` | Yes  | CLIENT, DRIVER, DISPATCHER | Get ride rating           |

## Ride Templates

| Method | Path                                | Auth | Roles                 | Description                  |
|--------|-------------------------------------|------|-----------------------|------------------------------|
| POST   | `/api/ride-templates`               | Yes  | DISPATCHER, SECRETARY | Create template              |
| GET    | `/api/ride-templates`               | Yes  | DISPATCHER, SECRETARY | List active templates        |
| DELETE | `/api/ride-templates/{id}`          | Yes  | DISPATCHER, SECRETARY | Deactivate template          |
| POST   | `/api/ride-templates/{id}/generate` | Yes  | DISPATCHER, SECRETARY | Generate rides from template |

## Ride Pools

| Method | Path                             | Auth | Roles              | Description               |
|--------|----------------------------------|------|--------------------|---------------------------|
| POST   | `/api/pools`                     | Yes  | DISPATCHER         | Create pool               |
| GET    | `/api/pools`                     | Yes  | DISPATCHER         | List pools                |
| GET    | `/api/pools/open`                | Yes  | DISPATCHER         | List open pools           |
| GET    | `/api/pools/{id}`                | Yes  | DISPATCHER, DRIVER | Get pool details          |
| POST   | `/api/pools/{id}/rides`          | Yes  | DISPATCHER         | Add ride to pool          |
| DELETE | `/api/pools/{id}/rides/{rideId}` | Yes  | DISPATCHER         | Remove ride from pool     |
| PUT    | `/api/pools/{id}/assign`         | Yes  | DISPATCHER         | Assign driver to pool     |
| PUT    | `/api/pools/{id}/status`         | Yes  | DISPATCHER, DRIVER | Update pool status        |
| GET    | `/api/pools/ride/{rideId}`       | Yes  | Any                | Find pool containing ride |

## Drivers

| Method | Path                                   | Auth | Roles                    | Description                |
|--------|----------------------------------------|------|--------------------------|----------------------------|
| PUT    | `/api/drivers/{driverId}/location`     | Yes  | Driver owner, DISPATCHER | Update driver GPS location |
| PUT    | `/api/drivers/{driverId}/availability` | Yes  | Driver owner, DISPATCHER | Update availability        |
| GET    | `/api/drivers/available`               | Yes  | DISPATCHER, SECRETARY    | List available drivers     |
| GET    | `/api/rides/{rideId}/driver-location`  | Yes  | Any                      | Get driver proximity info  |

## Schedules

| Method | Path                               | Auth | Roles | Description                                    |
|--------|------------------------------------|------|-------|------------------------------------------------|
| POST   | `/api/schedules`                   | Yes  | Any   | Create schedule day                            |
| POST   | `/api/schedules/batch`             | Yes  | Any   | Create multiple schedule days                  |
| GET    | `/api/schedules`                   | Yes  | Any   | Get schedules for date range (query: from, to) |
| GET    | `/api/schedules/driver/{driverId}` | Yes  | Any   | Get driver's schedule                          |
| GET    | `/api/schedules/day/{date}`        | Yes  | Any   | Get all schedules for date                     |
| PUT    | `/api/schedules/{id}`              | Yes  | Any   | Update schedule day                            |
| DELETE | `/api/schedules/{id}`              | Yes  | Any   | Cancel schedule day                            |

## Statistics

| Method | Path                            | Auth | Roles             | Description                                |
|--------|---------------------------------|------|-------------------|--------------------------------------------|
| GET    | `/api/stats/rides`              | Yes  | DISPATCHER, ADMIN | Ride statistics summary                    |
| GET    | `/api/stats/rides/daily`        | Yes  | DISPATCHER, ADMIN | Daily ride counts (query: days)            |
| GET    | `/api/stats/drivers`            | Yes  | DISPATCHER, ADMIN | Per-driver earnings and stats              |
| GET    | `/api/stats/payroll`            | Yes  | DISPATCHER        | Driver payroll (query: driverId, from, to) |
| GET    | `/api/stats/cancellations`      | Yes  | DISPATCHER        | Cancellation statistics                    |
| GET    | `/api/stats/peak-hours`         | Yes  | DISPATCHER        | Peak hours analysis (query: days)          |
| GET    | `/api/stats/client-value`       | Yes  | DISPATCHER        | Client lifetime value                      |
| GET    | `/api/stats/driver-performance` | Yes  | DISPATCHER        | Driver performance scorecard               |
| GET    | `/api/stats/driver-ratings`     | Yes  | DISPATCHER        | Driver average ratings                     |

## Expenses

| Method | Path                 | Auth | Roles                    | Description    |
|--------|----------------------|------|--------------------------|----------------|
| POST   | `/api/expenses`      | Yes  | DRIVER, DISPATCHER       | Create expense |
| GET    | `/api/expenses`      | Yes  | DRIVER, DISPATCHER       | List expenses  |
| DELETE | `/api/expenses/{id}` | Yes  | DRIVER owner, DISPATCHER | Delete expense |

## Export

| Method | Path                         | Auth | Roles      | Description                         |
|--------|------------------------------|------|------------|-------------------------------------|
| GET    | `/api/export/datev`          | Yes  | DISPATCHER, ADMIN | Export DATEV accounting data (JSON preview + copy)        |
| GET    | `/api/export/datev/rides`    | Yes  | DISPATCHER, ADMIN | Export rides as DATEV CSV                                 |
| GET    | `/api/export/datev/expenses` | Yes  | DISPATCHER, ADMIN | Export expenses as DATEV CSV                              |
| GET    | `/api/export/datev/extf`     | Yes  | DISPATCHER, ADMIN | Download DATEV EXTF/Buchungsstapel file (Windows-1252)    |

## Sessions

| Method | Path                 | Auth | Roles | Description               |
|--------|----------------------|------|-------|---------------------------|
| GET    | `/api/sessions`      | Yes  | Any   | List active sessions      |
| POST   | `/api/sessions`      | Yes  | Any   | Register new session      |
| DELETE | `/api/sessions/{id}` | Yes  | Any   | Revoke specific session   |
| DELETE | `/api/sessions`      | Yes  | Any   | Revoke all other sessions |

## Blacklist

| Method | Path                   | Auth | Roles                 | Description                                              |
|--------|------------------------|------|-----------------------|----------------------------------------------------------|
| GET    | `/api/blacklist`       | Yes  | DISPATCHER            | List blacklist entries                                   |
| POST   | `/api/blacklist`       | Yes  | DISPATCHER            | Add blacklist entry                                      |
| GET    | `/api/blacklist/check` | Yes  | DISPATCHER, SECRETARY | Check if pair is blacklisted (query: clientId, driverId) |
| DELETE | `/api/blacklist/{id}`  | Yes  | DISPATCHER            | Remove blacklist entry                                   |

## Company Settings

| Method | Path                    | Auth | Roles                                 | Description             |
|--------|-------------------------|------|---------------------------------------|-------------------------|
| GET    | `/api/company/settings` | Yes  | DISPATCHER                            | Get company settings    |
| PUT    | `/api/company/settings` | Yes  | DISPATCHER                            | Update company settings |
| GET    | `/api/company/tariff`   | Yes  | DISPATCHER, DRIVER, CLIENT, SECRETARY | Get tariff              |
| PUT    | `/api/company/tariff`   | Yes  | DISPATCHER                            | Update tariff           |

## Emergency

| Method | Path                                      | Auth | Roles      | Description                      |
|--------|-------------------------------------------|------|------------|----------------------------------|
| POST   | `/api/emergency/reassign`                 | Yes  | DISPATCHER | Emergency driver reassignment    |
| GET    | `/api/emergency/reassignments`            | Yes  | DISPATCHER | List reassignments               |
| GET    | `/api/emergency/suggest-drivers/{rideId}` | Yes  | DISPATCHER | Suggest drivers for reassignment |

## Notifications

| Method | Path                              | Auth | Roles | Description                                    |
|--------|-----------------------------------|------|-------|------------------------------------------------|
| GET    | `/api/notifications`              | Yes  | Any   | Get notifications (query: limit, offset, type) |
| GET    | `/api/notifications/unread-count` | Yes  | Any   | Unread count                                   |
| PUT    | `/api/notifications/{id}/read`    | Yes  | Any   | Mark as read                                   |
| PUT    | `/api/notifications/read-all`     | Yes  | Any   | Mark all as read                               |
| DELETE | `/api/notifications/{id}`         | Yes  | Any   | Delete notification                            |
| DELETE | `/api/notifications`              | Yes  | Any   | Delete all notifications                       |

## Notification Preferences

| Method | Path                            | Auth | Roles | Description        |
|--------|---------------------------------|------|-------|--------------------|
| GET    | `/api/notification-preferences` | Yes  | Any   | Get preferences    |
| PUT    | `/api/notification-preferences` | Yes  | Any   | Update preferences |

## Audit

| Method | Path                | Auth | Roles      | Description                                 |
|--------|---------------------|------|------------|---------------------------------------------|
| GET    | `/api/audit`        | Yes  | DISPATCHER | Get audit log (query: entityType, entityId) |
| GET    | `/api/audit/recent` | Yes  | DISPATCHER | Recent audit logs (query: limit, offset)    |

## GDPR

| Method | Path                         | Auth | Roles | Description           |
|--------|------------------------------|------|-------|-----------------------|
| GET    | `/api/gdpr/consents`         | Yes  | Any   | Get GDPR consents     |
| PUT    | `/api/gdpr/consents`         | Yes  | Any   | Update consent        |
| GET    | `/api/gdpr/export`           | Yes  | Any   | Export all user data  |
| POST   | `/api/gdpr/deletion-request` | Yes  | Any   | Request data deletion |
| GET    | `/api/gdpr/requests`         | Yes  | Any   | Get GDPR requests     |

## Geofences

| Method | Path                                      | Auth | Roles      | Description                  |
|--------|-------------------------------------------|------|------------|------------------------------|
| POST   | `/api/geofences`                          | Yes  | DISPATCHER | Create geofence              |
| GET    | `/api/geofences`                          | Yes  | DISPATCHER | List geofences               |
| PUT    | `/api/geofences/{id}`                     | Yes  | DISPATCHER | Update geofence              |
| DELETE | `/api/geofences/{id}`                     | Yes  | DISPATCHER | Delete geofence              |
| GET    | `/api/geofences/alerts`                   | Yes  | DISPATCHER | Recent alerts (query: limit) |
| GET    | `/api/geofences/alerts/driver/{driverId}` | Yes  | DISPATCHER | Driver alerts (query: limit) |

## Client Companies

Corporate client accounts that can have multiple individual client members.

| Method | Path                                 | Auth | Roles                        | Description               |
|--------|--------------------------------------|------|------------------------------|---------------------------|
| GET    | `/api/client-companies`              | Yes  | DISPATCHER, SECRETARY, ADMIN | List all client companies |
| POST   | `/api/client-companies`              | Yes  | DISPATCHER, ADMIN            | Create client company     |
| GET    | `/api/client-companies/{id}`         | Yes  | DISPATCHER, SECRETARY, ADMIN | Get company details       |
| PUT    | `/api/client-companies/{id}`         | Yes  | DISPATCHER, ADMIN            | Update company details    |
| DELETE | `/api/client-companies/{id}`         | Yes  | DISPATCHER, ADMIN            | Delete company            |
| GET    | `/api/client-companies/{id}/members` | Yes  | DISPATCHER, SECRETARY, ADMIN | List company members      |

## Billing

Invoice management and billing client companies. PDF generation and email delivery included.

### Billing Companies

| Method | Path                          | Auth | Roles                        | Description            |
|--------|-------------------------------|------|------------------------------|------------------------|
| GET    | `/api/billing/companies`      | Yes  | DISPATCHER, SECRETARY, ADMIN | List billing companies |
| POST   | `/api/billing/companies`      | Yes  | DISPATCHER, ADMIN            | Create billing company |
| PUT    | `/api/billing/companies/{id}` | Yes  | DISPATCHER, ADMIN            | Update billing company |
| DELETE | `/api/billing/companies/{id}` | Yes  | DISPATCHER, ADMIN            | Delete billing company |

### Invoices

| Method | Path                                   | Auth | Roles                        | Description                                  |
|--------|----------------------------------------|------|------------------------------|----------------------------------------------|
| GET    | `/api/billing/invoices`                | Yes  | DISPATCHER, SECRETARY, ADMIN | List invoices (filterable by status/company) |
| POST   | `/api/billing/invoices`                | Yes  | DISPATCHER, SECRETARY, ADMIN | Create invoice                               |
| GET    | `/api/billing/invoices/{id}`           | Yes  | DISPATCHER, SECRETARY, ADMIN | Get invoice details                          |
| POST   | `/api/billing/invoices/{id}/auto-fill` | Yes  | DISPATCHER, SECRETARY, ADMIN | Auto-fill invoice from completed rides       |
| GET    | `/api/billing/invoices/{id}/pdf`       | Yes  | DISPATCHER, SECRETARY, ADMIN | Download invoice as PDF                      |
| POST   | `/api/billing/invoices/{id}/send`      | Yes  | DISPATCHER, SECRETARY, ADMIN | Send invoice by email                        |
| POST   | `/api/billing/invoices/{id}/pay`       | Yes  | DISPATCHER, SECRETARY, ADMIN | Mark invoice as paid                         |
| DELETE | `/api/billing/invoices/{id}`           | Yes  | DISPATCHER, SECRETARY, ADMIN | Delete invoice                               |

## WebSocket

| Method | Path             | Auth                | Description                                   |
|--------|------------------|---------------------|-----------------------------------------------|
| POST   | `/api/ws/ticket` | Yes (JWT)           | Exchange JWT for short-lived WebSocket ticket |
| GET    | `/api/ws`        | Yes (JWT or ticket) | WebSocket connection for real-time events     |

### WebSocket Events
- Ride assignment, status changes, creation
- Geofence triggers
- Driver approaching notifications
- Company-scoped event filtering

## Authentication

Login returns a JWT `token` and user info. Pass the token as:

```
Authorization: Bearer <token>
```

JWT tokens expire after 24 hours. Maximum session duration: 90 days.

Authenticated endpoints extract the user's `companyId` from JWT claims for company isolation.
