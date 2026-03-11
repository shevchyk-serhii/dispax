# API Endpoints

All endpoints return JSON. Authenticated endpoints require `Authorization: Bearer <JWT>` header.

## Health

| Method | Path      | Auth | Description        |
|--------|-----------|------|--------------------|
| GET    | `/health` | No   | Health check       |

## Auth

| Method | Path              | Auth | Description                  |
|--------|-------------------|------|------------------------------|
| POST   | `/api/auth/login` | No   | Login (email + password), returns JWT token |

## Rides (authenticated)

| Method | Path                                    | Description                                      |
|--------|-----------------------------------------|--------------------------------------------------|
| POST   | `/api/rides`                            | Create a ride (user must belong to a company)     |
| GET    | `/api/rides`                            | Get rides for the authenticated user              |
| GET    | `/api/rides/pending`                    | Get all rides with `Requested` status             |
| GET    | `/api/rides/{rideId}`                   | Get ride by ID                                    |
| GET    | `/api/rides/driver/{driverId}`          | Get rides assigned to a specific driver            |
| PUT    | `/api/rides/{rideId}/assign-driver`     | Assign a driver to a ride (body: `{driverId}`)    |
| POST   | `/api/rides/{rideId}/airport-timing`    | Calculate airport entry timing for a ride          |

## Drivers (authenticated)

| Method | Path                                       | Description                                  |
|--------|--------------------------------------------|----------------------------------------------|
| PUT    | `/api/drivers/{driverId}/location`         | Update driver GPS location (`{latitude, longitude}`) |
| GET    | `/api/rides/{rideId}/driver-location`      | Get driver proximity info for a ride          |

## Schedules (authenticated)

| Method | Path                                       | Description                                     |
|--------|--------------------------------------------|-------------------------------------------------|
| POST   | `/api/schedules`                           | Create a single schedule day                     |
| POST   | `/api/schedules/batch`                     | Create multiple schedule days at once            |
| GET    | `/api/schedules?from={date}&to={date}`     | Get schedule days in date range (company-scoped) |
| GET    | `/api/schedules/driver/{driverId}`         | Get schedule for a specific driver (company-scoped) |
| GET    | `/api/schedules/day/{date}`                | Get all driver schedules for a date (company-scoped) |
| PUT    | `/api/schedules/{id}`                      | Update a schedule day                            |
| DELETE | `/api/schedules/{id}`                      | Cancel a schedule day                            |

## Users (public)

| Method | Path                    | Description              |
|--------|-------------------------|--------------------------|
| GET    | `/api/users`            | List all users           |
| GET    | `/api/users/{id}`       | Get user by ID           |
| GET    | `/api/users/drivers`    | List all drivers         |
| GET    | `/api/users/clients`    | List all clients         |
| GET    | `/api/stats/rides`      | Ride statistics summary  |

## Authentication

Login returns a `LoginResponse` with a JWT `token` and user info (`UserDto`). Pass the token as:

```
Authorization: Bearer <token>
```

Authenticated endpoints extract the user's `companyId` from the JWT claims to enforce company isolation.
