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

  Scenario: Download EXTF Buchungsstapel file authenticated
    Given I am authenticated as an admin
    When I send a GET request to "/api/export/datev/extf"
    Then the response status should be 200
    And the response should contain export data details

  Scenario: Download EXTF file with explicit month parameter
    Given I am authenticated as an admin
    When I send a GET request to "/api/export/datev/extf?month=2025-05"
    Then the response status should be 200
    And the response should contain export data details

  Scenario: Download EXTF file without authentication returns 401
    When I send a GET request to "/api/export/datev/extf" without authentication
    Then the response status should be 401

  Scenario: Company B token cannot access company A EXTF data (tenant isolation)
    Given I am authenticated as a dispatcher for company B
    When I send a GET request to "/api/export/datev/extf"
    Then the response status should be 200
    And the response body should not contain company A ride data
