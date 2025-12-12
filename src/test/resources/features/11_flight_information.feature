Feature: Flight Information System
  As a taxi service user
  I want to access flight arrival and departure information for any airport
  So that I can plan airport transfers effectively

  Background:
    Given the flight information system is available
    And the API server is running

  Scenario: Get flight arrivals for any airport
    When I request arrivals for airport "munich"
    Then I should receive a valid flight arrivals response
    And the response should contain flight data with ICAO codes
    And each arrival should have departure airport information

  Scenario: Get flight departures for any airport  
    When I request departures for airport "munich"
    Then I should receive a valid flight departures response
    And the response should contain flight data with ICAO codes
    And each departure should have arrival airport information

  Scenario: Support multiple airports
    When I request arrivals for airport "kiev"
    Then I should receive a valid flight arrivals response
    When I request departures for airport "london"
    Then I should receive a valid flight departures response
    When I request arrivals for airport "frankfurt"
    Then I should receive a valid flight arrivals response

  Scenario: Flight data structure validation
    When I request arrivals for airport "munich"
    Then each flight record should contain:
      | field               | type    | required |
      | icao24             | string  | true     |
      | firstSeen          | number  | true     |
      | lastSeen           | number  | true     |
      | estDepartureAirport| string  | true     |
      | estArrivalAirport  | string  | true     |
      | callsign           | string  | true     |

  Scenario: Time-based flight filtering
    When I request arrivals for airport "munich" with time parameters
      | begin | 1734087440 |
      | end   | 1734092840 |
    Then I should receive flights within the specified time range
    And all flights should have timestamps between the requested times

  Scenario: Error handling for invalid requests
    When I request arrivals for airport ""
    Then I should receive a valid response
    When I request departures for airport "invalid-airport"
    Then I should receive a valid response

  Scenario: API endpoint availability
    When I make a GET request to "/api/flights/munich/arrivals"
    Then the response status should be 200
    And the response content type should be "application/json"
    When I make a GET request to "/api/flights/kiev/departures"  
    Then the response status should be 200
    And the response content type should be "application/json"

  Scenario: Flight information consistency
    When I request arrivals for airport "munich"
    And I request departures for airport "munich"
    Then both responses should have the same data structure
    And both responses should be valid JSON arrays
    And each flight should have valid timestamp data

  Scenario: Frontend compatibility
    Given the Flutter frontend expects flight data
    When I request arrivals for airport "munich"
    Then the response should be compatible with FlightData model
    And timestamps should be convertible to DateTime objects
    And airport codes should be valid ICAO format