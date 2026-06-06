@api
Feature: Security & Data Isolation
  As the system
  I want to enforce company isolation and RBAC
  So that no tenant can access another tenant's data

  Background:
    Given the API is running

  # ── Company isolation ─────────────────────────────────────────────────────

  Scenario: Client cannot list all users
    Given I am authenticated as a client
    When I send a GET request to "/api/users"
    Then the response status should be 403

  Scenario: Driver cannot list all users
    Given I am authenticated as a driver
    When I send a GET request to "/api/users"
    Then the response status should be 403

  Scenario: Driver cannot access billing companies
    Given I am authenticated as a driver
    When I send a POST request to "/api/billing/companies" with body:
      """
      {"name":"Hacker Corp","email":"hack@evil.com"}
      """
    Then the response status should be 403

  Scenario: Driver cannot create invoices
    Given I am authenticated as a driver
    When I send a POST request to "/api/billing/invoices" with body:
      """
      {"clientCompanyId":"11111111-1111-1111-1111-111111111111","periodFrom":"2026-06-01","periodTo":"2026-06-30"}
      """
    Then the response status should be 403

  Scenario: Secretary cannot create billing companies
    Given I am authenticated as a secretary
    When I send a POST request to "/api/billing/companies" with body:
      """
      {"name":"Unauthorized Corp","email":"test@test.de"}
      """
    Then the response status should be 403

  Scenario: Client cannot access GDPR deletion requests list
    Given I am authenticated as a client
    When I send a GET request to "/api/gdpr/requests"
    Then the response status should be 403

  Scenario: Client cannot access audit log
    Given I am authenticated as a client
    When I send a GET request to "/api/audit"
    Then the response status should be 403

  Scenario: Unauthenticated access to rides returns 401
    When I send a GET request to "/api/rides" without authentication
    Then the response status should be 401

  Scenario: Unauthenticated access to users returns 401
    When I send a GET request to "/api/users" without authentication
    Then the response status should be 401

  Scenario: Invalid token returns 401
    When I send a GET request to "/api/rides" with invalid token
    Then the response status should be 401

  # ── Ride status machine — invalid transitions ──────────────────────────────

  Scenario: Cannot transition ride from Requested to InProgress directly
    Given I am authenticated as a dispatcher
    When I send a PUT request to "/api/rides/88888888-8888-8888-8888-888888888888/status" with body:
      """
      {"status":"InProgress"}
      """
    Then the response status should be 409

  Scenario: Cannot assign driver to already-assigned ride
    Given I am authenticated as a dispatcher
    When I send a PUT request to "/api/rides/11111111-1111-1111-1111-111111111111/assign-driver" with body:
      """
      {"driverId":"33333333-3333-3333-3333-333333333333"}
      """
    Then the response status should be 409

  # ── Input validation ───────────────────────────────────────────────────────

  Scenario: Cannot create ride with past pickup time
    Given I am authenticated as a dispatcher
    When I send a POST request to "/api/rides" with body:
      """
      {"pickupLocation":{"address":"Hauptbahnhof"},"dropoffLocation":{"address":"Airport"},"pickupTime":"2020-01-01T08:00:00Z","clientId":"11111111-1111-1111-1111-111111111111"}
      """
    Then the response status should be 400

  Scenario: Cannot create ride without pickup location
    Given I am authenticated as a dispatcher
    When I send a POST request to "/api/rides" with body:
      """
      {"dropoffLocation":{"address":"Airport"},"pickupTime":"2030-01-01T08:00:00Z","clientId":"11111111-1111-1111-1111-111111111111"}
      """
    Then the response status should be 400

  Scenario: Cannot get ride with malformed UUID
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/rides/not-a-valid-uuid"
    Then the response status should be 400
