@api
Feature: Notification Management
  As a user
  I want to manage my in-app notifications
  So that I can stay informed and control what I see

  Background:
    Given the API is running

  Scenario: Get notifications list
    Given I am authenticated as a client
    When I send a GET request to "/api/notifications"
    Then the response status should be 200
    And the response should contain notification entries

  Scenario: Get unread notification count
    Given I am authenticated as a client
    When I send a GET request to "/api/notifications/unread-count"
    Then the response status should be 200
    And the response should contain unread count details

  Scenario: Mark notification as read
    Given I am authenticated as a client
    When I send a PUT request to "/api/notifications/11111111-1111-1111-1111-111111111111/read" with body:
      """
      {}
      """
    Then the response status should be 200

  Scenario: Mark all notifications as read
    Given I am authenticated as a client
    When I send a PUT request to "/api/notifications/read-all" with body:
      """
      {}
      """
    Then the response status should be 200

  Scenario: Delete a notification
    Given I am authenticated as a client
    When I send a DELETE request to "/api/notifications/11111111-1111-1111-1111-111111111111"
    Then the response status should be 204

  Scenario: Get notification preferences
    Given I am authenticated as a client
    When I send a GET request to "/api/notification-preferences"
    Then the response status should be 200
    And the response should contain notification preference details

  Scenario: Update notification preferences
    Given I am authenticated as a client
    When I send a PUT request to "/api/notification-preferences" with body:
      """
      {"emailEnabled":true,"smsEnabled":false,"pushEnabled":true}
      """
    Then the response status should be 200
    And the response should contain notification preference details

  Scenario: Get notifications without authentication
    When I send a GET request to "/api/notifications" without authentication
    Then the response status should be 401
