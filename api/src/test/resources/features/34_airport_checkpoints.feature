@api
Feature: Airport Checkpoint Map for MUC Arrival Transfers
  As a client arriving at Munich Airport
  I want to mark my current location in the terminal
  So that my driver knows where to find me

  Background:
    Given the API is running

  Scenario: Client marks Landed for an in-progress arrival ride
    Given I am authenticated as a client with ID 1
    When I send a POST request to "/api/rides/eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee/airport-checkpoint" with body:
      """
      {"checkpoint":"landed"}
      """
    Then the response status should be 204

  Scenario: Client cannot mark same checkpoint twice
    Given I am authenticated as a client with ID 1
    When I send a POST request to "/api/rides/eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee/airport-checkpoint" with body:
      """
      {"checkpoint":"landed"}
      """
    And I send a POST request to "/api/rides/eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee/airport-checkpoint" with body:
      """
      {"checkpoint":"landed"}
      """
    Then the response status should be 422

  Scenario: Client marks forward from Landed to ArrivalsHall
    Given I am authenticated as a client with ID 1
    When I send a POST request to "/api/rides/eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee/airport-checkpoint" with body:
      """
      {"checkpoint":"arrivals_hall"}
      """
    Then the response status should be 204

  Scenario: Client skips from None directly to TerminalExit (skip-ahead allowed)
    Given I am authenticated as a client with ID 1
    When I send a POST request to "/api/rides/eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee/airport-checkpoint" with body:
      """
      {"checkpoint":"terminal_exit"}
      """
    Then the response status should be 204

  Scenario: Driver retrieves current checkpoint state
    Given I am authenticated as a driver with ID 2
    When I send a GET request to "/api/rides/11111111-1111-1111-1111-111111111111/airport-checkpoint"
    Then the response status should be 200

  Scenario: Cross-tenant access returns 404
    Given I am authenticated as a client with ID 1
    When I send a GET request to "/api/rides/99999999-9999-9999-9999-999999999999/airport-checkpoint"
    Then the response status should be 404

  Scenario: Non-CLIENT role cannot mark checkpoint
    Given I am authenticated as a dispatcher
    When I send a POST request to "/api/rides/11111111-1111-1111-1111-111111111111/airport-checkpoint" with body:
      """
      {"checkpoint":"landed"}
      """
    Then the response status should be 403
