@api
Feature: Statistics and Reports
  As an administrator
  I want to access various statistics
  So that I can make data-driven decisions

  Background:
    Given the API is running

  Scenario: Get ride statistics
    Given I am authenticated as an admin
    When I send a GET request to "/api/stats/rides"
    Then the response status should be 200
    And the response should contain ride statistics details

  Scenario: Get daily ride statistics
    Given I am authenticated as an admin
    When I send a GET request to "/api/stats/rides/daily"
    Then the response status should be 200
    And the response should contain ride statistics details

  Scenario: Get driver statistics
    Given I am authenticated as an admin
    When I send a GET request to "/api/stats/drivers"
    Then the response status should be 200
    And the response should contain driver statistics details

  Scenario: Get payroll statistics
    Given I am authenticated as an admin
    When I send a GET request to "/api/stats/payroll"
    Then the response status should be 200
    And the response should contain payroll statistics details

  Scenario: Get cancellation statistics
    Given I am authenticated as an admin
    When I send a GET request to "/api/stats/cancellations"
    Then the response status should be 200
    And the response should contain cancellation statistics details

  Scenario: Get peak hours statistics
    Given I am authenticated as an admin
    When I send a GET request to "/api/stats/peak-hours"
    Then the response status should be 200
    And the response should contain peak hours statistics details

  Scenario: Get client value statistics
    Given I am authenticated as an admin
    When I send a GET request to "/api/stats/client-value"
    Then the response status should be 200
    And the response should contain client value statistics details

  Scenario: Get driver performance statistics
    Given I am authenticated as an admin
    When I send a GET request to "/api/stats/driver-performance"
    Then the response status should be 200
    And the response should contain driver performance statistics details

  Scenario: Get statistics without authentication
    When I send a GET request to "/api/stats/rides" without authentication
    Then the response status should be 401
