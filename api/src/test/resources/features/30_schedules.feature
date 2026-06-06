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
      {"driverId":"10101010-1010-1010-1010-101010101010","date":"2026-06-02","startTime":"08:00","endTime":"18:00"}
      """
    Then the response status should be 201
    And the response should contain schedule details

  Scenario: Create schedules in batch
    Given I am authenticated as a dispatcher
    When I send a POST request to "/api/schedules/batch" with body:
      """
      {"driverId":"10101010-1010-1010-1010-101010101010","days":[{"date":"2026-07-01","startTime":"08:00","endTime":"18:00"},{"date":"2026-07-02","startTime":"10:00","endTime":"20:00"}]}
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
    When I send a GET request to "/api/schedules?from=2026-06-01&to=2026-06-30"
    Then the response status should be 200
    And the response should contain schedule entries

  Scenario: Get schedules without authentication
    When I send a GET request to "/api/schedules" without authentication
    Then the response status should be 401
