# API Endpoints

All endpoints return JSON. Authenticated endpoints require `Authorization: Bearer <JWT>` header.

## Health

| Method | Path      | Auth | Description  |
|--------|-----------|------|--------------|
| GET    | `/health` | No   | Health check |

## Auth

| Method | Path                               | Auth | Description                                                |
|--------|------------------------------------|------|------------------------------------------------------------|
| POST   | `/api/auth/login`                  | No   | Login (email + password), returns JWT token. Rate limited. |
| GET    | `/api/auth/validate`               | Yes  | Validate the current bearer token                          |
| POST   | `/api/auth/logout`                 | No   | Log out (stateless stub)                                   |
| POST   | `/api/auth/password/reset-request` | No   | Request a password reset link                              |
| POST   | `/api/auth/biometric/setup`        | No   | Enable biometric login (stub)                              |

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
| GET    | `/api/users/profile`           | Yes  | Any                          | Get own profile                                 |
| PUT    | `/api/users/profile`           | Yes  | Any                          | Update own profile (privileged fields rejected) |
| POST   | `/api/users/{id}/avatar`       | Yes  | DISPATCHER, ADMIN, or owner  | Upload or replace profile photo                 |
| GET    | `/api/users/{id}/avatar`       | Yes  | Any (same company)           | Serve profile photo bytes (tenant-isolated)     |
| DELETE | `/api/users/{id}/avatar`       | Yes  | DISPATCHER, ADMIN, or owner  | Remove profile photo                            |
| PUT    | `/api/users/{id}/upgrade-provisional` | Yes | DISPATCHER, DRIVER, ADMIN | Promote a provisional client to a real client   |
| POST   | `/api/users/password/change`   | No   | —                            | Change password (public stub)                   |

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
| POST   | `/api/rides/estimate`                 | Yes  | DRIVER, CLIENT, DISPATCHER, SECRETARY, ADMIN | Estimate distance, duration and price     |
| GET    | `/api/rides/by-drivers`               | Yes  | DISPATCHER, DRIVER                    | List rides for multiple drivers (bulk, date-scoped) |
| PUT    | `/api/rides/{rideId}/confirm`         | Yes  | DRIVER                                | Driver confirms the assigned ride                |
| PUT    | `/api/rides/{rideId}/reject`          | Yes  | DRIVER                                | Driver rejects the assigned ride with a reason   |
| PUT    | `/api/rides/{rideId}/hand-off`        | Yes  | DISPATCHER, ADMIN                     | Hand off a ride to an external driver            |
| PUT    | `/api/rides/{rideId}/price`           | Yes  | DISPATCHER, DRIVER                    | Set the final price of a ride                    |
| POST   | `/api/rides/{rideId}/refresh-flight`  | Yes  | DISPATCHER, DRIVER, SECRETARY         | Refresh a ride's flight status on demand         |
| POST   | `/api/rides/{rideId}/airport-checkpoint` | Yes | CLIENT                             | Mark the client's current airport checkpoint     |
| GET    | `/api/rides/{rideId}/airport-checkpoint` | Yes | CLIENT, DRIVER, DISPATCHER          | Get the current airport checkpoint state         |

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
| GET    | `/api/drivers/{driverId}/availability` | Yes  | DISPATCHER, SECRETARY, or owner | Get a driver's availability status |
| GET    | `/api/drivers/{driverId}/earnings`     | Yes  | DISPATCHER, or owner     | Get a driver's earnings report |

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

## Schedule Visibility & Unavailability

| Method | Path                                              | Auth | Roles                                  | Description                                            |
|--------|---------------------------------------------------|------|----------------------------------------|--------------------------------------------------------|
| GET    | `/api/schedules/visibility`                       | Yes  | DISPATCHER, ADMIN                      | List per-driver schedule-visibility settings           |
| GET    | `/api/schedules/visibility/me`                    | Yes  | Any                                    | Get the caller's own schedule-visibility flag          |
| PUT    | `/api/schedules/visibility/{driverId}`            | Yes  | DISPATCHER, ADMIN                      | Set whether a driver may view others' schedules        |
| POST   | `/api/schedules/unavailability`                   | Yes  | DRIVER (self only)                     | Mark a driver unavailability window                    |
| GET    | `/api/schedules/unavailability`                   | Yes  | DISPATCHER, ADMIN                      | List company unavailability windows in a range         |
| GET    | `/api/schedules/unavailability/driver/{driverId}` | Yes  | Access-controlled (self / staff / visible) | Get unavailability windows for a driver           |
| DELETE | `/api/schedules/unavailability/{id}`              | Yes  | owner, DISPATCHER, ADMIN               | Delete a driver unavailability window                  |

## Calendar Sharing

Cross-company calendar sharing via invite codes (PII-free shared calendars).

| Method | Path                                          | Auth | Roles                       | Description                                    |
|--------|-----------------------------------------------|------|-----------------------------|------------------------------------------------|
| POST   | `/api/calendar-shares/invites`                | Yes  | DRIVER, DISPATCHER, ADMIN   | Mint an invite code for the caller's calendar  |
| GET    | `/api/calendar-shares/invites`                | Yes  | DRIVER, DISPATCHER, ADMIN   | List the caller's active invites               |
| DELETE | `/api/calendar-shares/invites/{inviteId}`     | Yes  | DRIVER, DISPATCHER, ADMIN   | Revoke one of the caller's invites             |
| POST   | `/api/calendar-shares/redeem`                 | Yes  | DRIVER, DISPATCHER, ADMIN   | Redeem an invite code as the calling user      |
| GET    | `/api/calendar-shares/granted`                | Yes  | DRIVER, DISPATCHER, ADMIN   | List active grants where the caller is grantor |
| DELETE | `/api/calendar-shares/granted/{grantId}`      | Yes  | DRIVER, DISPATCHER, ADMIN   | Revoke a grant the caller issued               |
| GET    | `/api/calendar-shares/shared-with-me`         | Yes  | DRIVER, DISPATCHER, ADMIN   | List active grants where the caller is grantee |
| DELETE | `/api/calendar-shares/shared-with-me/{grantId}` | Yes | DRIVER, DISPATCHER, ADMIN  | Unlink a calendar shared with the caller       |
| GET    | `/api/calendar-shares/{grantId}/calendar`     | Yes  | grantee (DRIVER/DISPATCHER/ADMIN) | Read the shared PII-free calendar        |

## Client Addresses

Saved pickup/drop-off addresses per client.

| Method | Path                                            | Auth | Roles                              | Description                |
|--------|-------------------------------------------------|------|------------------------------------|----------------------------|
| GET    | `/api/clients/{clientId}/addresses`             | Yes  | DISPATCHER, SECRETARY, DRIVER, or owner | List a client's saved addresses |
| POST   | `/api/clients/{clientId}/addresses`             | Yes  | DISPATCHER, SECRETARY, or owner    | Save a client address      |
| PATCH  | `/api/clients/{clientId}/addresses/{addressId}` | Yes  | DISPATCHER, SECRETARY, or owner    | Update a client address    |
| DELETE | `/api/clients/{clientId}/addresses/{addressId}` | Yes  | DISPATCHER, SECRETARY, or owner    | Delete a client address    |

## Partner & External Companies

Partner companies and external drivers for cross-company ride hand-off.

| Method | Path                      | Auth | Roles             | Description                              |
|--------|---------------------------|------|-------------------|------------------------------------------|
| GET    | `/api/partner-companies`  | Yes  | DISPATCHER, ADMIN | List partner companies for the tenant    |
| POST   | `/api/partner-companies`  | Yes  | DISPATCHER, ADMIN | Create a partner company                 |
| GET    | `/api/external-drivers`   | Yes  | DISPATCHER, ADMIN | List external drivers for the tenant     |
| POST   | `/api/external-drivers`   | Yes  | DISPATCHER, ADMIN | Create an external driver                |

## Flights

Munich Airport (MUC) flight board, used for airport-transfer timing.

| Method | Path                     | Auth | Roles                                 | Description                            |
|--------|--------------------------|------|---------------------------------------|----------------------------------------|
| GET    | `/api/flights/arrivals`  | Yes  | DRIVER, SECRETARY, DISPATCHER, ADMIN  | MUC flights board (arrivals/departures) |
| GET    | `/api/flights/lookup`    | Yes  | DRIVER, SECRETARY, DISPATCHER, ADMIN  | MUC single-flight lookup (with gate)   |

## Tracking

Public guest tracking links (token-based, no JWT) plus the secured link-creation endpoint.

| Method | Path                                  | Auth | Roles                         | Description                                    |
|--------|---------------------------------------|------|-------------------------------|------------------------------------------------|
| POST   | `/api/rides/{rideId}/share-link`      | Yes  | DRIVER, DISPATCHER, SECRETARY | Create (or reuse) a public guest tracking link |
| GET    | `/api/track/{token}`                  | No   | —                             | Public ride state for a guest tracking token   |
| GET    | `/api/track/{token}/locations`        | No   | —                             | Public driver location for a guest token       |
| POST   | `/api/track/{token}/checkpoint`       | No   | —                             | Passenger self-reports an airport checkpoint   |

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

| Method | Path                         | Auth | Roles             | Description                                            |
|--------|------------------------------|------|-------------------|--------------------------------------------------------|
| GET    | `/api/export/datev`          | Yes  | DISPATCHER, ADMIN | Export DATEV accounting data (JSON preview + copy)     |
| GET    | `/api/export/datev/rides`    | Yes  | DISPATCHER, ADMIN | Export rides as DATEV CSV                              |
| GET    | `/api/export/datev/expenses` | Yes  | DISPATCHER, ADMIN | Export expenses as DATEV CSV                           |
| GET    | `/api/export/datev/extf`     | Yes  | DISPATCHER, ADMIN | Download DATEV EXTF/Buchungsstapel file (Windows-1252) |

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

### Billing Profile

| Method | Path                   | Auth | Roles             | Description                                    |
|--------|------------------------|------|-------------------|------------------------------------------------|
| GET    | `/api/billing/profile` | Yes  | DISPATCHER, ADMIN | Get the company's invoice issuer details       |
| PUT    | `/api/billing/profile` | Yes  | DISPATCHER, ADMIN | Create or update the company's issuer details  |

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
| POST   | `/api/billing/invoices/{id}/fill-from-rides` | Yes | DISPATCHER, SECRETARY, ADMIN | Fill an invoice from explicit unbilled rides |
| GET    | `/api/billing/billable-rides`          | Yes  | DISPATCHER, SECRETARY, ADMIN | List completed, unbilled rides for invoicing |
| GET    | `/api/billing/rides/{rideId}/receipt`  | Yes  | DISPATCHER, SECRETARY, ADMIN | Download a single-ride receipt (Quittung) PDF |

## SuperAdmin

Platform-level administration (cross-tenant). All endpoints require the `SUPER_ADMIN` role.

### Companies & Analytics

| Method | Path                                    | Auth | Roles       | Description                            |
|--------|-----------------------------------------|------|-------------|----------------------------------------|
| GET    | `/api/superadmin/companies`             | Yes  | SUPER_ADMIN | List all tenant companies              |
| GET    | `/api/superadmin/companies/{id}`        | Yes  | SUPER_ADMIN | Get a single company by ID             |
| POST   | `/api/superadmin/companies`             | Yes  | SUPER_ADMIN | Create (onboard) a new tenant company  |
| PATCH  | `/api/superadmin/companies/{id}`        | Yes  | SUPER_ADMIN | Update company status / subscription   |
| DELETE | `/api/superadmin/companies/{id}`        | Yes  | SUPER_ADMIN | Soft-delete (deactivate) a company     |
| GET    | `/api/superadmin/analytics/rides`       | Yes  | SUPER_ADMIN | Cross-tenant ride analytics            |
| GET    | `/api/superadmin/analytics/billing`     | Yes  | SUPER_ADMIN | Cross-tenant billing analytics         |
| GET    | `/api/superadmin/analytics/connections` | Yes  | SUPER_ADMIN | Platform-wide active session counts    |

### Airports

| Method | Path                                                | Auth | Roles       | Description                          |
|--------|-----------------------------------------------------|------|-------------|--------------------------------------|
| GET    | `/api/superadmin/airports`                          | Yes  | SUPER_ADMIN | List all airports                    |
| GET    | `/api/superadmin/airports/{code}`                   | Yes  | SUPER_ADMIN | Get a single airport by IATA code    |
| POST   | `/api/superadmin/airports`                          | Yes  | SUPER_ADMIN | Create a new airport configuration   |
| PATCH  | `/api/superadmin/airports/{code}`                   | Yes  | SUPER_ADMIN | Update airport configuration         |
| DELETE | `/api/superadmin/airports/{code}`                   | Yes  | SUPER_ADMIN | Soft-deactivate an airport           |
| POST   | `/api/superadmin/airports/{code}/zones`             | Yes  | SUPER_ADMIN | Add a checkpoint zone to an airport  |
| PATCH  | `/api/superadmin/airports/{code}/zones/{zoneId}`    | Yes  | SUPER_ADMIN | Update a checkpoint zone             |
| DELETE | `/api/superadmin/airports/{code}/zones/{zoneId}`    | Yes  | SUPER_ADMIN | Delete a checkpoint zone             |

## Version

| Method | Path           | Auth | Description                          |
|--------|----------------|------|--------------------------------------|
| GET    | `/api/version` | No   | Build/version info (public, no auth) |

## WebSocket

| Method | Path             | Auth                | Description                                   |
|--------|------------------|---------------------|-----------------------------------------------|
| POST   | `/api/ws/ticket` | Yes (JWT)           | Exchange JWT for short-lived WebSocket ticket |
| GET    | `/api/ws`        | Yes (JWT or ticket) | WebSocket connection for real-time events     |
| GET    | `/api/ws/track`  | No (guest token)    | Public guest tracking WebSocket (query `?token=`) |

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

## Infrastructure

Non-Tapir routes (not part of the JSON API surface); token-based routes validate their own token, not a JWT.

| Method | Path             | Auth | Description                                          |
|--------|------------------|------|-----------------------------------------------------|
| GET    | `/health`        | No   | Health check                                        |
| GET    | `/health/ready`  | No   | Readiness probe (pings DB; 503 if unreachable)      |
| POST   | `/api/dev/reset` | No   | Truncate transactional tables (dev only; 403 otherwise) |
| GET    | `/track/{token}` | No   | Server-rendered guest tracking HTML page            |
