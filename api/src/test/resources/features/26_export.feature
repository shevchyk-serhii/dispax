@api
Feature: DATEV Export
  As an administrator
  I want to export financial data in DATEV format
  So that I can process it in accounting software

  Background:
    Given the API is running

  Scenario: Export all DATEV data
    Given I am authenticated as an admin
    When I send a GET request to "/api/export/datev"
    Then the response status should be 200
    And the response should contain export data details

  Scenario: Export rides in DATEV format
    Given I am authenticated as an admin
    When I send a GET request to "/api/export/datev/rides"
    Then the response status should be 200
    And the response should contain export data details

  Scenario: Export expenses in DATEV format
    Given I am authenticated as an admin
    When I send a GET request to "/api/export/datev/expenses"
    Then the response status should be 200
    And the response should contain export data details

  Scenario: Export without authentication
    When I send a GET request to "/api/export/datev" without authentication
    Then the response status should be 401
