@api
Feature: Session Management
  As a user
  I want to manage my active sessions
  So that I can control device access

  Background:
    Given the API is running

  Scenario: Get active sessions
    Given I am authenticated as a client
    When I send a GET request to "/api/sessions"
    Then the response status should be 200
    And the response should contain session entries

  Scenario: Create a session
    Given I am authenticated as a client
    When I send a POST request to "/api/sessions" with body:
      """
      {"deviceInfo":"iPhone 15","ipAddress":"192.168.1.1"}
      """
    Then the response status should be 201
    And the response should contain session details

  Scenario: Delete a specific session
    Given I am authenticated as a client
    When I send a DELETE request to "/api/sessions/11111111-1111-1111-1111-111111111111"
    Then the response status should be 204

  Scenario: Delete all sessions
    Given I am authenticated as a client
    When I send a DELETE request to "/api/sessions"
    Then the response status should be 204

  Scenario: Get sessions without authentication
    When I send a GET request to "/api/sessions" without authentication
    Then the response status should be 401
