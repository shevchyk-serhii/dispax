@api
Feature: Driver Location and Availability
  As a driver
  I want to update my location and availability
  So that dispatchers can assign rides efficiently

  Background:
    Given the API is running

  Scenario: Update driver location
    Given I am authenticated as a driver
    When I send a PUT request to "/api/drivers/22222222-2222-2222-2222-222222222222/location" with body:
      """
      {"latitude":48.1351,"longitude":11.5820,"heading":90.0}
      """
    Then the response status should be 200

  Scenario: Update driver availability
    Given I am authenticated as a driver
    When I send a PUT request to "/api/drivers/22222222-2222-2222-2222-222222222222/availability" with body:
      """
      {"available":true}
      """
    Then the response status should be 200

  Scenario: Get driver availability
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/drivers/22222222-2222-2222-2222-222222222222/availability"
    Then the response status should be 200
    And the response should contain driver availability details

  Scenario: Get available drivers
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/drivers/available"
    Then the response status should be 200
    And the response should contain available driver entries

  Scenario: Get driver location for a ride
    Given I am authenticated as a client
    When I send a GET request to "/api/rides/11111111-1111-1111-1111-111111111111/driver-location"
    Then the response status should be 200
    And the response should contain driver location details

  Scenario: Update driver location without authentication
    When I send a PUT request to "/api/drivers/22222222-2222-2222-2222-222222222222/location" without authentication
    Then the response status should be 401
