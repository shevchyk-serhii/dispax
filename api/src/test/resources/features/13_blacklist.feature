@api
Feature: Blacklist Management
  As an administrator
  I want to manage the blacklist
  So that I can block problematic users

  Background:
    Given the API is running

  Scenario: Get blacklist as admin
    Given I am authenticated as an admin
    When I send a GET request to "/api/blacklist"
    Then the response status should be 200
    And the response should contain blacklist entries

  Scenario: Add person to blacklist
    Given I am authenticated as an admin
    When I send a POST request to "/api/blacklist" with body:
      """
      {"personId":"11111111-1111-1111-1111-111111111111","reason":"Repeated no-shows"}
      """
    Then the response status should be 201
    And the response should contain blacklist entry details

  Scenario: Check if person is blacklisted
    Given I am authenticated as an admin
    When I send a GET request to "/api/blacklist/check?personId=11111111-1111-1111-1111-111111111111"
    Then the response status should be 200
    And the response should contain blacklist check details

  Scenario: Remove person from blacklist
    Given I am authenticated as an admin
    When I send a DELETE request to "/api/blacklist/11111111-1111-1111-1111-111111111111"
    Then the response status should be 204

  Scenario: Get blacklist without authentication
    When I send a GET request to "/api/blacklist" without authentication
    Then the response status should be 401
