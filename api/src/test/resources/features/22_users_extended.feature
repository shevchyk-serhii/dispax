@api
Feature: Extended User Management
  As an administrator or user
  I want to access user statistics and manage FCM tokens
  So that I can operate the system effectively

  Background:
    Given the API is running

  Scenario: Get all users as admin
    Given I am authenticated as an admin
    When I send a GET request to "/api/users"
    Then the response status should be 200
    And the response should contain user entries

  Scenario: Get driver users list
    Given I am authenticated as an admin
    When I send a GET request to "/api/users/drivers"
    Then the response status should be 200
    And the response should contain driver user entries

  Scenario: Get client users list
    Given I am authenticated as an admin
    When I send a GET request to "/api/users/clients"
    Then the response status should be 200
    And the response should contain client user entries

  Scenario: Get user statistics
    Given I am authenticated as an admin
    When I send a GET request to "/api/users/stats"
    Then the response status should be 200
    And the response should contain user statistics details

  Scenario: Change password
    Given I am authenticated as a client
    When I send a PUT request to "/api/users/change-password" with body:
      """
      {"currentPassword":"Password123","newPassword":"NewPass1!"}
      """
    Then the response status should be 204

  Scenario: Register FCM token
    Given I am authenticated as a client
    When I send a POST request to "/api/users/fcm-token" with body:
      """
      {"token":"fcm-device-token-abc123","platform":"android"}
      """
    Then the response status should be 201

  Scenario: Delete FCM token
    Given I am authenticated as a client
    When I send a DELETE request to "/api/users/fcm-token/fcm-device-token-abc123"
    Then the response status should be 204

  Scenario: Update driver reminder minutes
    Given I am authenticated as a driver
    When I send a PUT request to "/api/users/reminder-minutes" with body:
      """
      {"minutes":30}
      """
    Then the response status should be 204

  Scenario: Get users without authentication
    When I send a GET request to "/api/users" without authentication
    Then the response status should be 401
