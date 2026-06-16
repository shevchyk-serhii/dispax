@api
Feature: SuperAdmin Company Management
  As a platform SuperAdmin
  I want to manage tenant companies
  So that I can onboard and administrate operators

  Background:
    Given the API is running

  # ── Positive scenarios (SuperAdmin access) ───────────────────────────────

  Scenario: SuperAdmin lists all tenant companies
    Given I am authenticated as a superadmin
    When I send a GET request to "/api/superadmin/companies"
    Then the response status should be 200

  Scenario: SuperAdmin can create a new tenant company
    Given I am authenticated as a superadmin
    When I send a POST request to "/api/superadmin/companies" with body:
      """
      {"name":"New Taxi GmbH","email":"new@taxi.de","phone":"+491234567890","address":"Leopoldstraße 1, München"}
      """
    Then the response status should be 201

  # ── Negative tenant-isolation scenarios ──────────────────────────────────

  Scenario: Admin cannot access superadmin company list
    Given I am authenticated as an admin
    When I send a GET request to "/api/superadmin/companies"
    Then the response status should be 403

  Scenario: Dispatcher cannot access superadmin company list
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/superadmin/companies"
    Then the response status should be 403

  Scenario: Driver cannot access superadmin company list
    Given I am authenticated as a driver
    When I send a GET request to "/api/superadmin/companies"
    Then the response status should be 403

  Scenario: Client cannot access superadmin company list
    Given I am authenticated as a client
    When I send a GET request to "/api/superadmin/companies"
    Then the response status should be 403

  Scenario: Unauthenticated request to superadmin companies returns 401
    When I send a GET request to "/api/superadmin/companies" without authentication
    Then the response status should be 401

  Scenario: Admin cannot create a company via superadmin endpoint
    Given I am authenticated as an admin
    When I send a POST request to "/api/superadmin/companies" with body:
      """
      {"name":"Hacker Corp","email":"hack@evil.de","phone":"+491111","address":"Hacker Str."}
      """
    Then the response status should be 403

  # ── Soft-delete (deactivate) scenarios ───────────────────────────────────

  Scenario: SuperAdmin deactivates a company — endpoint is accessible (escape-hatch allows)
    # The in-memory stub returns 404 because no real company is seeded, but the
    # 404 proves the SuperAdmin passed the role-gate. A 200 with Inactive body
    # is verified at the HTTP unit-test level (SuperAdminApiSpec).
    Given I am authenticated as a superadmin
    When I send a DELETE request to "/api/superadmin/companies/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
    Then the response status should be 404

  Scenario: Admin cannot deactivate a company via superadmin endpoint (escape-hatch negative test)
    Given I am authenticated as an admin
    When I send a DELETE request to "/api/superadmin/companies/10101010-1010-1010-1010-101010101010"
    Then the response status should be 403
