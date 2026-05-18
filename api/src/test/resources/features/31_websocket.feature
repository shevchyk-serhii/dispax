@api
Feature: WebSocket Connection
  As a client application
  I want to obtain a WebSocket ticket and connect
  So that I receive real-time updates

  Background:
    Given the API is running

  Scenario: Obtain WebSocket ticket
    Given I am authenticated as a client
    When I send a POST request to "/api/ws/ticket" with body:
      """
      {}
      """
    Then the response status should be 200
    And the response should contain websocket ticket details

  Scenario: Obtain WebSocket ticket without authentication
    When I send a POST request to "/api/ws/ticket" without authentication
    Then the response status should be 401
