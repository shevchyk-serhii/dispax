@api
Feature: Ride Management
  As a taxi service
  I want to manage ride requests and assignments
  So that customers can book rides and drivers can fulfill them

  Background:
    Given the API is running

  Scenario: Create a basic ride request
    Given I am authenticated as a dispatcher
    When I send a POST request to "/api/rides" with body:
      """
      {"clientId":"11111111-1111-1111-1111-111111111111","creatorId":"33333333-3333-3333-3333-333333333333","clientName":"Test User","from":{"address":"Hauptbahnhof München"},"to":{"address":"Flughafen München"},"pickupDateTime":"2026-12-10T15:30:00Z"}
      """
    Then the response status should be 201
    And the response should contain ride details

  Scenario: Get ride by ID
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/rides/11111111-1111-1111-1111-111111111111"
    Then the response status should be 200
    And the response should contain ride details

  Scenario: Get non-existent ride
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/rides/00000000-0000-0000-0000-000000000001"
    Then the response status should be 404

  Scenario: Assign driver to ride
    Given I am authenticated as a dispatcher
    When I send a PUT request to "/api/rides/22222222-2222-2222-2222-222222222222/assign-driver" with body:
      """
      {"driverId":"10101010-1010-1010-1010-101010101010"}
      """
    Then the response status should be 200

  Scenario: Create a ride with an unknown driver returns a typed error, not 500
    Given I am authenticated as a dispatcher
    When I send a POST request to "/api/rides" with body:
      """
      {"clientId":"11111111-1111-1111-1111-111111111111","creatorId":"33333333-3333-3333-3333-333333333333","clientName":"Test User","from":{"address":"Hauptbahnhof München"},"to":{"address":"Flughafen München"},"pickupDateTime":"2026-12-10T15:30:00Z","driverId":"00000000-0000-0000-0000-0000000000aa"}
      """
    Then the response status should be 404

  Scenario: Update ride status to in progress
    Given I am authenticated as a driver
    When I send a PUT request to "/api/rides/11111111-1111-1111-1111-111111111111/status" with body:
      """
      {"status":"InProgress"}
      """
    Then the response status should be 200

  # A driver may opt in to "Assign to me" while creating a ride. The ride is
  # always created into the pool first; the self-assign is best-effort. When it
  # conflicts with an existing ride (30-min buffer), the create still succeeds
  # (201) and the ride stays in the pool unassigned (status Requested) instead
  # of the whole request failing with 409 — the ride must never be lost.
  Scenario: Self-assign on create stays in the pool when it conflicts
    Given I am authenticated as a dispatcher
    And I send a POST request to "/api/rides" with body:
      """
      {"clientId":"11111111-1111-1111-1111-111111111111","creatorId":"33333333-3333-3333-3333-333333333333","clientName":"Test User","from":{"address":"Hauptbahnhof München"},"to":{"address":"Flughafen München"},"pickupDateTime":"2026-12-12T09:00:00Z","driverId":"10101010-1010-1010-1010-101010101010"}
      """
    And the response status should be 201
    When I send a POST request to "/api/rides" with body:
      """
      {"clientId":"11111111-1111-1111-1111-111111111111","creatorId":"33333333-3333-3333-3333-333333333333","clientName":"Test User","from":{"address":"Hauptbahnhof München"},"to":{"address":"Flughafen München"},"pickupDateTime":"2026-12-12T09:10:00Z","driverId":"10101010-1010-1010-1010-101010101010"}
      """
    Then the response status should be 201
    And the response should contain "Requested"
