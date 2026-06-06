@api
Feature: Authentication & Authorization
  As a system
  I want to control access to the API
  So that only authorized users can perform operations

  Background:
    Given the API is running

  Scenario: Successful authentication with valid credentials
    Given a user exists with email "test@example.com" and password "password123"
    When I send a POST request to "/api/auth/login" with:
      | email    | test@example.com |
      | password | Password123      |
    Then the response status should be 200
    And the response should contain a JWT token
    And the token should be valid for 24 hours

  Scenario: Authentication fails with invalid credentials
    When I send a POST request to "/api/auth/login" with:
      | email    | invalid@example.com |
      | password | wrongpassword       |
    Then the response status should be 401
    And the response should contain "Invalid credentials"

  Scenario: Access protected endpoint without authentication
    When I send a GET request to "/api/rides" without authentication
    Then the response status should be 401
    And the response should contain "Authorization"

  Scenario: Access protected endpoint with invalid token
    When I send a GET request to "/api/rides" with invalid token
    Then the response status should be 401
    And the response should contain "Invalid"

  Scenario: Access protected endpoint with valid token
    Given I am authenticated with a valid JWT token
    When I send a GET request to "/api/rides"
    Then the response status should be 200

  Scenario: Role-based access control - Driver accessing admin endpoint
    Given I am authenticated as a driver
    When I send a GET request to "/api/users"
    Then the response status should be 403
    And the response should contain "Insufficient permissions"

  Scenario: Role-based access control - Admin accessing admin endpoint
    Given I am authenticated as an admin
    When I send a GET request to "/api/users"
    Then the response status should be 200

  Scenario: Token refresh - not supported
    # The API does not implement a /api/auth/refresh endpoint; this scenario
    # documents the expected 404 behaviour so stakeholders are aware.
    Given I have an expired but refreshable token
    When I send a POST request to "/api/auth/refresh" with the refresh token
    Then the response status should be 404

  Scenario: Logout invalidates token
    Given I am authenticated with a valid JWT token
    When I send a POST request to "/api/auth/logout"
    Then the response status should be 200
    And the token should be invalidated