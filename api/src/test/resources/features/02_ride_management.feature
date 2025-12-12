@api
Feature: Ride Management
  As a taxi service
  I want to manage ride requests and assignments
  So that customers can book rides and drivers can fulfill them

  Background:
    Given the API is running
    And the following test data exists:
      | PersonId | Name         | Role       | Email                    |
      | 1        | John Client  | Client     | john.client@example.com  |
      | 2        | Jane Driver  | Driver     | jane.driver@example.com  |
      | 3        | Bob Dispatch | Dispatcher | bob.dispatch@example.com |

  Scenario: Create a basic ride request
    Given I am authenticated as a client with ID 1
    When I create a ride request with:
      | clientId    | 1                    |
      | pickup      | Kyiv Airport         |
      | destination | Khreschatyk Street   |
      | scheduledAt | 2024-12-10T15:30:00Z |
    Then the response status should be 201
    And the response should contain ride details
    And the ride status should be "Pending"

  Scenario: Create an airport transfer ride
    Given I am authenticated as a client with ID 1
    When I create an airport transfer ride with:
      | clientId        | 1                    |
      | pickup          | Boryspil Airport     |
      | destination     | City Center          |
      | scheduledAt     | 2024-12-10T16:00:00Z |
      | flightNumber    | KL1234               |
      | isAirportPickup | true                 |
    Then the response status should be 201
    And the response should contain airport transfer details
    And the ride should have flight information

  Scenario: Get ride by ID
    Given I am authenticated as a dispatcher with ID 3
    And a ride exists with ID 123
    When I send a GET request to "/api/v2/rides/123"
    Then the response status should be 200
    And the response should contain ride details with ID 123

  Scenario: Get non-existent ride
    Given I am authenticated as a dispatcher with ID 3
    When I send a GET request to "/api/v2/rides/999999"
    Then the response status should be 404
    And the response should contain "Ride not found"

  Scenario: Assign driver to ride
    Given I am authenticated as a dispatcher with ID 3
    And a pending ride exists with ID 456
    And driver with ID 2 is available
    When I assign driver 2 to ride 456
    Then the response status should be 200
    And the ride status should be "Assigned"
    And the driver should be notified

  Scenario: Update ride status to in progress
    Given I am authenticated as a driver with ID 2
    And I am assigned to ride with ID 789
    When I update the ride status to "InProgress"
    Then the response status should be 200
    And the ride status should be "InProgress"
    And the client should be notified

  Scenario: Complete a ride
    Given I am authenticated as a driver with ID 2
    And I have an in-progress ride with ID 101
    When I update the ride status to "Completed"
    Then the response status should be 200
    And the ride status should be "Completed"
    And the client should receive completion notification