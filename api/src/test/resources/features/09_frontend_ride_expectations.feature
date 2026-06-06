# Frontend Ride Management Expectations
# Tests for ride API endpoints that Flutter frontend expects to exist
@api @frontend-rides
Feature: Frontend Ride Management API Expectations

  Background:
    Given the API is running

  @rides @list
  Scenario: Frontend expects to get list of all rides
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/rides"
    Then the response status should be 200
    And the response should contain ride entries

  @rides @get @single
  Scenario: Frontend expects to get single ride by ID
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/rides/11111111-1111-1111-1111-111111111111"
    Then the response status should be 200
    And the response should contain ride details

  @rides @get @notfound
  Scenario: Frontend expects 404 for non-existent ride
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/rides/00000000-0000-0000-0000-000000000000"
    Then the response status should be 404

  @rides @create
  Scenario: Frontend expects to create new ride
    Given I am authenticated as a dispatcher
    When I send a POST request to "/api/rides" with body:
      """
      {"clientId":"11111111-1111-1111-1111-111111111111","creatorId":"33333333-3333-3333-3333-333333333333","clientName":"Test User","from":{"address":"Airport Terminal 1"},"to":{"address":"Hotel Paradise"},"pickupDateTime":"2026-12-15T10:30:00Z"}
      """
    Then the response status should be 201
    And the response should contain ride details

  @rides @driver @assign
  Scenario: Frontend expects to assign driver to ride
    Given I am authenticated as a dispatcher
    When I send a PUT request to "/api/rides/77777777-7777-7777-7777-777777777777/assign-driver" with body:
      """
      {"driverId":"10101010-1010-1010-1010-101010101010"}
      """
    Then the response status should be 200

  @rides @driver @filter
  Scenario: Frontend expects to get rides filtered by driver
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/rides/driver/10101010-1010-1010-1010-101010101010"
    Then the response status should be 200
    And the response should contain ride entries

  @rides @status @filter
  Scenario: Frontend expects to get pending rides
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/rides/pending"
    Then the response status should be 200
    And the response should contain ride entries

  @rides @cancel
  Scenario: Frontend expects to cancel ride
    Given I am authenticated as a dispatcher
    When I send a PUT request to "/api/rides/77777777-7777-7777-7777-777777777777/cancel" with body:
      """
      {"reason":"Client request"}
      """
    Then the response status should be 200

  @rides @validation @error
  Scenario: Frontend expects 400 for invalid ride data
    Given I am authenticated as a dispatcher
    When I send a POST request to "/api/rides" with body:
      """
      {"pickupLocation":""}
      """
    Then the response status should be 400
