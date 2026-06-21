@api
Feature: Ride fare estimate
  As a client
  I want to estimate a fare before booking
  So that I know the price for a given route and vehicle class

  Background:
    Given the API is running

  Scenario: Estimate a fare for a route with coordinates
    Given I am authenticated as a client
    When I send a POST request to "/api/rides/estimate" with body:
      """
      {"from":{"address":"Marienplatz","latitude":48.1374,"longitude":11.5755},"to":{"address":"Munich Airport","latitude":48.3537,"longitude":11.7750},"vehicleClass":"business","isAirportTransfer":true}
      """
    Then the response status should be 200
    And the response should contain "estimatedPrice"
    And the response should contain "distanceKm"
    And the response should contain "durationMinutes"

  Scenario: Estimate a fare from free-text addresses (server geocodes them)
    Given I am authenticated as a client
    When I send a POST request to "/api/rides/estimate" with body:
      """
      {"from":{"address":"Marienplatz, München"},"to":{"address":"Flughafen München"},"vehicleClass":"business","isAirportTransfer":true}
      """
    Then the response status should be 200
    And the response should contain "estimatedPrice"
    And the response should contain "distanceKm"

  Scenario: Estimate fails when the address cannot be geocoded
    Given I am authenticated as a client
    When I send a POST request to "/api/rides/estimate" with body:
      """
      {"from":{"address":"Nonexistent place 99999"},"to":{"address":"Another unknown place 88888"},"vehicleClass":"business"}
      """
    Then the response status should be 400

  Scenario: Estimate requires authentication
    When I send a POST request to "/api/rides/estimate" without authentication
    Then the response status should be 401
