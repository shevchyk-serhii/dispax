@api
Feature: Emergency Reassignment
  As a dispatcher
  I want to manage emergency ride reassignments
  So that I can handle driver emergencies

  Background:
    Given the API is running

  Scenario: Trigger emergency reassignment
    Given I am authenticated as a dispatcher
    When I send a POST request to "/api/emergency/reassign" with body:
      """
      {"rideId":"33333333-3333-3333-3333-333333333333","reason":"Accident"}
      """
    Then the response status should be 201
    And the response should contain reassignment details

  Scenario: Get emergency reassignments list
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/emergency/reassignments"
    Then the response status should be 200
    And the response should contain emergency reassignment entries

  Scenario: Get suggested drivers for emergency reassignment
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/emergency/suggest-drivers/11111111-1111-1111-1111-111111111111"
    Then the response status should be 200
    And the response should contain suggested driver entries

  Scenario: Emergency reassignment without authentication
    When I send a POST request to "/api/emergency/reassign" without authentication
    Then the response status should be 401
