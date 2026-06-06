@api
Feature: Ride Pool Management
  As a dispatcher
  I want to manage ride pools
  So that I can group rides for efficient assignment

  Background:
    Given the API is running

  Scenario: Create a ride pool
    Given I am authenticated as a dispatcher
    When I send a POST request to "/api/pools" with body:
      """
      {"name":"Airport Morning Pool","scheduledDate":"2026-06-01"}
      """
    Then the response status should be 201
    And the response should contain pool details

  Scenario: Get all ride pools
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/pools"
    Then the response status should be 200
    And the response should contain pool entries

  Scenario: Get open ride pools
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/pools/open"
    Then the response status should be 200
    And the response should contain pool entries

  Scenario: Get ride pool by ID
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/pools/11111111-1111-1111-1111-111111111111"
    Then the response status should be 200
    And the response should contain pool details

  Scenario: Add ride to pool
    Given I am authenticated as a dispatcher
    When I send a POST request to "/api/pools/11111111-1111-1111-1111-111111111111/rides" with body:
      """
      {"rideId":"22222222-2222-2222-2222-222222222222"}
      """
    Then the response status should be 201
    And the response should contain pool details

  Scenario: Remove ride from pool
    Given I am authenticated as a dispatcher
    When I send a DELETE request to "/api/pools/11111111-1111-1111-1111-111111111111/rides/22222222-2222-2222-2222-222222222222"
    Then the response status should be 204

  Scenario: Assign driver to pool
    Given I am authenticated as a dispatcher
    When I send a PUT request to "/api/pools/11111111-1111-1111-1111-111111111111/assign" with body:
      """
      {"driverId":"33333333-3333-3333-3333-333333333333"}
      """
    Then the response status should be 200
    And the response should contain pool details

  Scenario: Update pool status
    Given I am authenticated as a dispatcher
    When I send a PUT request to "/api/pools/11111111-1111-1111-1111-111111111111/status" with body:
      """
      {"status":"Cancelled"}
      """
    Then the response status should be 200
    And the response should contain pool details

  Scenario: Get pool for a specific ride
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/pools/ride/11111111-1111-1111-1111-111111111111"
    Then the response status should be 404

  Scenario: Get pools without authentication
    When I send a GET request to "/api/pools" without authentication
    Then the response status should be 401
