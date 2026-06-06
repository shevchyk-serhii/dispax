@api
Feature: Ride Templates
  As a dispatcher
  I want to manage ride templates
  So that I can quickly create recurring rides

  Background:
    Given the API is running

  Scenario: Create a ride template
    Given I am authenticated as a dispatcher
    When I send a POST request to "/api/ride-templates" with body:
      """
      {"clientId":"11111111-1111-1111-1111-111111111111","name":"Airport Monday Morning","fromAddress":"Office Munich","toAddress":"MUC Airport","pickupTime":"07:00","recurrencePattern":"WEEKDAYS"}
      """
    Then the response status should be 201
    And the response should contain ride template details

  Scenario: Get all ride templates
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/ride-templates"
    Then the response status should be 200
    And the response should contain ride template entries

  Scenario: Delete a ride template
    Given I am authenticated as a dispatcher
    When I send a DELETE request to "/api/ride-templates/11111111-1111-1111-1111-111111111111"
    Then the response status should be 204

  Scenario: Generate ride from template
    Given I am authenticated as a dispatcher
    When I send a POST request to "/api/ride-templates/11111111-1111-1111-1111-111111111111/generate" with body:
      """
      {"fromDate":"2026-07-01","toDate":"2026-07-07"}
      """
    Then the response status should be 201
    And the response should contain ride details

  Scenario: Get ride templates without authentication
    When I send a GET request to "/api/ride-templates" without authentication
    Then the response status should be 401
