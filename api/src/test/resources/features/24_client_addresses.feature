@api
Feature: Client Address Book
  As a client
  I want to manage my saved addresses
  So that I can quickly book rides to frequent destinations

  Background:
    Given the API is running

  Scenario: Get client addresses
    Given I am authenticated as a client
    When I send a GET request to "/api/clients/11111111-1111-1111-1111-111111111111/addresses"
    Then the response status should be 200
    And the response should contain address entries

  Scenario: Add a client address
    Given I am authenticated as a client
    When I send a POST request to "/api/clients/11111111-1111-1111-1111-111111111111/addresses" with body:
      """
      {"label":"Home","address":"Leopoldstraße 1, Munich"}
      """
    Then the response status should be 201
    And the response should contain address details

  Scenario: Delete a client address
    Given I am authenticated as a client
    When I send a DELETE request to "/api/clients/11111111-1111-1111-1111-111111111111/addresses/22222222-2222-2222-2222-222222222222"
    Then the response status should be 204

  Scenario: Get client addresses without authentication
    When I send a GET request to "/api/clients/11111111-1111-1111-1111-111111111111/addresses" without authentication
    Then the response status should be 401
