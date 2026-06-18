@api @avatar
Feature: User profile photo upload
  As a user of the Dispax platform
  I want to upload, view, and remove my profile photo
  So that my identity is recognizable in the app

  Background:
    Given the API is running

  # ── Upload ──────────────────────────────────────────────────────────────────

  @avatar @upload
  Scenario: User uploads their own profile photo
    Given I am authenticated as a client
    When I upload a JPEG image to "/api/users/50505050-5050-5050-5050-505050505050/avatar"
    Then the response status should be 200
    And the response should contain "true"

  @avatar @upload @dispatcher
  Scenario: Dispatcher uploads profile photo for a user in their company
    Given I am authenticated as a dispatcher
    When I upload a JPEG image to "/api/users/11111111-1111-1111-1111-111111111111/avatar"
    Then the response status should be 200

  # ── Get avatar ──────────────────────────────────────────────────────────────

  @avatar @serve
  Scenario: Request own avatar when no avatar is set returns 404
    Given I am authenticated as a client
    When I send a GET request to "/api/users/50505050-5050-5050-5050-505050505050/avatar"
    Then the response status should be 404

  @avatar @serve @unauthenticated
  Scenario: GET avatar without authentication returns 401
    When I send a GET request to "/api/users/50505050-5050-5050-5050-505050505050/avatar" without authentication
    Then the response status should be 401

  # ── Delete ──────────────────────────────────────────────────────────────────

  @avatar @delete
  Scenario: User deletes own profile photo
    Given I am authenticated as a client
    When I send a DELETE request to "/api/users/50505050-5050-5050-5050-505050505050/avatar"
    Then the response status should be 204

  # ── Tenant isolation — CRITICAL ─────────────────────────────────────────────

  @avatar @tenant-isolation @security
  Scenario: Cannot GET avatar of user in another company — returns 404
    # testPersonId1 (client, companyA = 10101010) tries to GET avatar of
    # a user that does NOT belong to their company (unknown ID).
    # The endpoint must return 404 — not 200, not 403 — to avoid leaking tenant existence.
    Given I am authenticated as a client
    When I send a GET request to "/api/users/ffffffff-ffff-ffff-ffff-ffffffffffff/avatar"
    Then the response status should be 404

  @avatar @tenant-isolation @security
  Scenario: Cannot DELETE avatar of user in another company — returns 404
    # testPersonId1 (client, companyA) tries to DELETE avatar of
    # a user from a different company. Must get 404.
    Given I am authenticated as a client
    When I send a DELETE request to "/api/users/ffffffff-ffff-ffff-ffff-ffffffffffff/avatar"
    Then the response status should be 404
