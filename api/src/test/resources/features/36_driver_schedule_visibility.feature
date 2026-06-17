@api
Feature: Configurable driver schedule visibility
  As a dispatcher
  I want to control whether a driver can view colleagues' calendars
  So that privacy and access are managed per policy

  Background:
    Given the API is running

  # ── Dispatcher enables visibility for a driver ────────────────────────────────

  Scenario: Dispatcher enables schedule visibility for a driver
    Given I am authenticated as a dispatcher
    When I send a PUT request to "/api/schedules/visibility/10101010-1010-1010-1010-101010101010" with body:
      """
      {"canViewOtherSchedules": true}
      """
    Then the response status should be 200
    And the response should contain "canViewOtherSchedules"

  # ── Dispatcher disables visibility for a driver ───────────────────────────────

  Scenario: Dispatcher disables schedule visibility for a driver
    Given I am authenticated as a dispatcher
    When I send a PUT request to "/api/schedules/visibility/10101010-1010-1010-1010-101010101010" with body:
      """
      {"canViewOtherSchedules": false}
      """
    Then the response status should be 200
    And the response should contain "canViewOtherSchedules"

  # ── Admin can also manage visibility ─────────────────────────────────────────

  Scenario: Admin enables schedule visibility for a driver
    Given I am authenticated as an admin
    When I send a PUT request to "/api/schedules/visibility/10101010-1010-1010-1010-101010101010" with body:
      """
      {"canViewOtherSchedules": true}
      """
    Then the response status should be 200
    And the response should contain "canViewOtherSchedules"

  # ── Dispatcher can read company visibility list ───────────────────────────────

  Scenario: Dispatcher reads company visibility settings
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/schedules/visibility"
    Then the response status should be 200

  # ── Driver is FORBIDDEN to access company visibility endpoint ────────────────
  # This documents the existing access control rule:
  # GET /api/schedules/visibility is protected by requireDispatcherOrAdmin.
  # A driver who calls this endpoint will receive 403.

  Scenario: Driver is forbidden to read company visibility settings
    Given I am authenticated as a driver with ID 10
    When I send a GET request to "/api/schedules/visibility"
    Then the response status should be 403

  # ── Driver is FORBIDDEN to manage visibility ──────────────────────────────────

  Scenario: Driver cannot set visibility for another driver
    Given I am authenticated as a driver with ID 10
    When I send a PUT request to "/api/schedules/visibility/10101010-1010-1010-1010-101010101010" with body:
      """
      {"canViewOtherSchedules": true}
      """
    Then the response status should be 403

  # ── Driver can view own schedule regardless of visibility flag ────────────────

  Scenario: Driver views own schedule — always allowed
    Given I am authenticated as a driver with ID 10
    When I send a GET request to "/api/schedules/driver/10101010-1010-1010-1010-101010101010"
    Then the response status should be 200

  # ── Driver without permission cannot view another driver's schedule ───────────

  Scenario: Driver without canViewOtherSchedules sees 403 for another driver's schedule
    Given I am authenticated as a driver with ID 10
    When I send a GET request to "/api/schedules/driver/33333333-3333-3333-3333-333333333333"
    Then the response status should be 403

  # ── Driver can read OWN visibility flag via /me ───────────────────────────────
  # GET /api/schedules/visibility/me is accessible to any authenticated role.
  # A driver who has no explicit record receives a safe default (canViewOtherSchedules=false).

  Scenario: Driver reads own visibility flag via /me endpoint — returns 200
    Given I am authenticated as a driver with ID 10
    When I send a GET request to "/api/schedules/visibility/me"
    Then the response status should be 200
    And the response should contain "canViewOtherSchedules"

  # ── Driver is STILL FORBIDDEN on the company-wide list ───────────────────────
  # Even though a driver can read /me, the general GET /api/schedules/visibility
  # (which returns all drivers' settings) remains restricted to Dispatcher / Admin.

  Scenario: Driver who can read /me is still forbidden on company visibility list
    Given I am authenticated as a driver with ID 10
    When I send a GET request to "/api/schedules/visibility"
    Then the response status should be 403

  # ── Unauthenticated access is blocked ────────────────────────────────────────

  Scenario: Unauthenticated request to visibility endpoint is rejected
    When I send a GET request to "/api/schedules/visibility" without authentication
    Then the response status should be 401

  Scenario: Unauthenticated request to /me visibility endpoint is rejected
    When I send a GET request to "/api/schedules/visibility/me" without authentication
    Then the response status should be 401
