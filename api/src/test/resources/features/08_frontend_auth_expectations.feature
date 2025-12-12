# Frontend Authentication Expectations
# Tests for API endpoints that Flutter frontend expects to exist
@api @frontend-auth
Feature: Frontend Authentication API Expectations
  
  Background:
    Given the API server is running at "http://127.0.0.1:8080"

  @auth @login
  Scenario: Frontend expects login endpoint to authenticate users
    When I make a POST request to "/api/auth/login" with JSON:
      """
      {
        "email": "test@example.com",
        "password": "password123"
      }
      """
    Then the response status should be 200
    And the response should contain JSON:
      """
      {
        "person": {
          "id": 1,
          "email": "test@example.com",
          "name": "Test User",
          "role": "CLIENT"
        },
        "token": "jwt-token-here"
      }
      """

  @auth @login @error
  Scenario: Frontend expects 401 for invalid credentials
    When I make a POST request to "/api/auth/login" with JSON:
      """
      {
        "email": "invalid@example.com", 
        "password": "wrongpassword"
      }
      """
    Then the response status should be 401
    And the response should be empty

  @auth @login @validation
  Scenario: Frontend expects 400 for malformed login data
    When I make a POST request to "/api/auth/login" with JSON:
      """
      {
        "email": "not-an-email",
        "password": ""
      }
      """
    Then the response status should be 400

  @auth @biometric
  Scenario: Frontend expects biometric authentication support
    Given I am authenticated as a client with ID 1
    When I make a POST request to "/api/auth/biometric/setup" with JSON:
      """
      {
        "enabled": true,
        "deviceId": "device-123"
      }
      """
    Then the response status should be 200
    And the response should contain JSON:
      """
      {
        "success": true,
        "biometricEnabled": true
      }
      """

  @auth @token @validation
  Scenario: Frontend expects token validation endpoint
    Given I am authenticated as a client with ID 1
    When I make a GET request to "/api/auth/validate"
    Then the response status should be 200
    And the response should contain JSON:
      """
      {
        "valid": true,
        "person": {
          "id": 1,
          "email": "test@example.com",
          "role": "CLIENT"
        }
      }
      """

  @auth @token @expired
  Scenario: Frontend expects 401 for expired/invalid tokens
    Given I have an invalid auth token "invalid-token"
    When I make a GET request to "/api/auth/validate"
    Then the response status should be 401

  @auth @logout
  Scenario: Frontend expects logout endpoint
    Given I am authenticated as a client with ID 1  
    When I make a POST request to "/api/auth/logout"
    Then the response status should be 200
    And the response should contain JSON:
      """
      {
        "success": true
      }
      """

  @auth @password @reset
  Scenario: Frontend expects password reset functionality
    When I make a POST request to "/api/auth/password/reset-request" with JSON:
      """
      {
        "email": "test@example.com"
      }
      """
    Then the response status should be 200
    And the response should contain JSON:
      """
      {
        "success": true,
        "message": "Reset email sent"
      }
      """