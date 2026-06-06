@api
Feature: Audit Log
  As an administrator
  I want to access audit logs
  So that I can track system activity

  Background:
    Given the API is running

  Scenario: Get audit log as admin
    Given I am authenticated as an admin
    When I send a GET request to "/api/audit/recent"
    Then the response status should be 200
    And the response should contain audit entries

  Scenario: Get recent audit entries as admin
    Given I am authenticated as an admin
    When I send a GET request to "/api/audit/recent"
    Then the response status should be 200
    And the response should contain recent audit entries

  Scenario: Get audit log without authentication
    When I send a GET request to "/api/audit/recent" without authentication
    Then the response status should be 401

  Scenario: Get audit log as non-admin client
    Given I am authenticated as a client
    When I send a GET request to "/api/audit/recent"
    Then the response status should be 403
