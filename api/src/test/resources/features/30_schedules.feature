@api
Feature: Driver Schedule Management
  As a dispatcher
  I want to manage driver schedules
  So that I can plan the work week

  Background:
    Given the API is running

  Scenario: Create a schedule day
    Given I am authenticated as a dispatcher
    When I send a POST request to "/api/schedules" with body:
      """
      {"driverId":"22222222-2222-2222-2222-222222222222","date":"2026-06-02","shiftStart":"08:00","shiftEnd":"18:00"}
      """
    Then the response status should be 201
    And the response should contain schedule details

  Scenario: Create schedules in batch
    Given I am authenticated as a dispatcher
    When I send a POST request to "/api/schedules/batch" with body:
      """
      {"schedules":[{"driverId":"22222222-2222-2222-2222-222222222222","date":"2026-06-02","shiftStart":"08:00","shiftEnd":"18:00"},{"driverId":"33333333-3333-3333-3333-333333333333","date":"2026-06-02","shiftStart":"10:00","shiftEnd":"20:00"}]}
      """
    Then the response status should be 201
    And the response should contain schedule entries

  Scenario: Get schedules for a driver
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/schedules/driver/22222222-2222-2222-2222-222222222222"
    Then the response status should be 200
    And the response should contain schedule entries

  Scenario: Get schedules for a specific day
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/schedules/day/2026-06-02"
    Then the response status should be 200
    And the response should contain schedule entries

  Scenario: Get all schedules
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/schedules"
    Then the response status should be 200
    And the response should contain schedule entries

  Scenario: Get schedules without authentication
    When I send a GET request to "/api/schedules" without authentication
    Then the response status should be 401
