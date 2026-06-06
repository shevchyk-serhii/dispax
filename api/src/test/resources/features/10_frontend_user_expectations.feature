# Frontend User Management Expectations
# Tests for user API endpoints that Flutter frontend expects to exist
@api @frontend-users
Feature: Frontend User Management API Expectations

  Background:
    Given the API is running

  @users @list
  Scenario: Frontend expects to get list of all users
    Given I am authenticated as an admin
    When I send a GET request to "/api/users"
    Then the response status should be 200
    And the response should contain user entries

  @users @get @single
  Scenario: Frontend expects to get single user by ID
    Given I am authenticated as an admin
    When I send a GET request to "/api/users/11111111-1111-1111-1111-111111111111"
    Then the response status should be 200
    And the response should contain user details

  @users @get @profile
  Scenario: Frontend expects current user profile endpoint
    Given I am authenticated as a client
    When I send a GET request to "/api/users/profile"
    Then the response status should be 200
    And the response should contain user details

  @users @create
  Scenario: Frontend expects to create new user
    Given I am authenticated as an admin
    When I send a POST request to "/api/users" with body:
      """
      {
        "email": "newuser@example.com",
        "name": "New User",
        "role": "Client",
        "phone": "+1234567890",
        "password": "Password123!"
      }
      """
    Then the response status should be 201
    And the response should contain user details

  @users @create @duplicate
  Scenario: Frontend expects 409 for duplicate email
    Given I am authenticated as an admin
    When I send a POST request to "/api/users" with body:
      """
      {
        "email": "test@example.com",
        "name": "Duplicate User",
        "role": "Client",
        "password": "Password123!"
      }
      """
    Then the response status should be 409

  @users @role @filter
  Scenario: Frontend expects to get users filtered by role
    Given I am authenticated as an admin
    When I send a GET request to "/api/users?role=Driver"
    Then the response status should be 200
    And the response should contain user entries

  @users @authorization
  Scenario: Frontend expects 403 for unauthorized access to admin endpoints
    Given I am authenticated as a client
    When I send a GET request to "/api/users"
    Then the response status should be 403
