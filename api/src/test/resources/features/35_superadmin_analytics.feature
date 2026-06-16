@api
Feature: SuperAdmin Platform Analytics
  As a platform SuperAdmin
  I want to view cross-tenant platform analytics
  So that I can monitor the health and revenue of all operators

  Background:
    Given the API is running

  # ── Positive scenarios (SuperAdmin access) ───────────────────────────────

  Scenario: SuperAdmin retrieves platform ride statistics
    Given I am authenticated as a superadmin
    When I send a GET request to "/api/superadmin/analytics/rides"
    Then the response status should be 200

  Scenario: SuperAdmin retrieves platform billing analytics
    Given I am authenticated as a superadmin
    When I send a GET request to "/api/superadmin/analytics/billing"
    Then the response status should be 200

  Scenario: SuperAdmin retrieves active connection counts
    Given I am authenticated as a superadmin
    When I send a GET request to "/api/superadmin/analytics/connections"
    Then the response status should be 200

  # ── Negative tenant-isolation scenarios ──────────────────────────────────

  Scenario: Admin cannot access ride analytics
    Given I am authenticated as an admin
    When I send a GET request to "/api/superadmin/analytics/rides"
    Then the response status should be 403

  Scenario: Dispatcher cannot access billing analytics
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/superadmin/analytics/billing"
    Then the response status should be 403

  Scenario: Driver cannot access connection analytics
    Given I am authenticated as a driver
    When I send a GET request to "/api/superadmin/analytics/connections"
    Then the response status should be 403

  Scenario: Unauthenticated request to ride analytics returns 401
    When I send a GET request to "/api/superadmin/analytics/rides" without authentication
    Then the response status should be 401

  Scenario: Unauthenticated request to billing analytics returns 401
    When I send a GET request to "/api/superadmin/analytics/billing" without authentication
    Then the response status should be 401
