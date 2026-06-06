# Frontend Authentication Expectations
# Tests for API endpoints that Flutter frontend expects to exist
@api @frontend-auth
Feature: Frontend Authentication API Expectations

  Background:
    Given the API is running

  @auth @login
  Scenario: Frontend expects login endpoint to authenticate users
    When I send a POST request to "/api/auth/login" with:
      | email    | test@example.com |
      | password | Password123      |
    Then the response status should be 200
    And the response should contain auth token details

  @auth @login @error
  Scenario: Frontend expects 401 for invalid credentials
    When I send a POST request to "/api/auth/login" with:
      | email    | invalid@example.com |
      | password | wrongpassword       |
    Then the response status should be 401

  @auth @login @validation
  Scenario: Frontend expects 401 for malformed login data
    When I send a POST request to "/api/auth/login" with:
      | email    | not-an-email |
      | password |              |
    Then the response status should be 401

  @auth @token @validation
  Scenario: Frontend expects token validation endpoint
    Given I am authenticated as a client
    When I send a GET request to "/api/auth/validate"
    Then the response status should be 200

  @auth @token @expired
  Scenario: Frontend expects 401 for expired/invalid tokens
    When I send a GET request to "/api/auth/validate" without authentication
    Then the response status should be 401

  @auth @logout
  Scenario: Frontend expects logout endpoint
    Given I am authenticated as a client
    When I send a POST request to "/api/auth/logout" with body:
      """
      {}
      """
    Then the response status should be 200
