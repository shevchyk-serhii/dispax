@api
Feature: Driver Operations
  As a driver
  I want to manage my availability and ride assignments
  So that I can efficiently serve customers

  Background:
    Given the API is running
    And the following drivers exist:
      | PersonId | Name        | Email                 | LicenseNumber | Status    |
      | 10       | Mike Driver | mike@example.com      | DL123456      | Available |
      | 11       | Sara Driver | sara@example.com      | DL789012      | Busy      |
      | 12       | Alex Driver | alex@example.com      | DL345678      | Offline   |

  Scenario: Get available drivers
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/v2/drivers/available"
    Then the response status should be 200
    And the response should contain 1 available drivers
    And driver "Mike Driver" should be in the list

  Scenario: Get driver profile
    Given I am authenticated as driver with ID 10
    When I send a GET request to "/api/v2/drivers/10/profile"
    Then the response status should be 200
    And the response should contain driver details
    And the status should be "Available"

  Scenario: Update driver status to busy
    Given I am authenticated as driver with ID 10
    When I update my status to "Busy"
    Then the response status should be 200
    And my status should be "Busy"

  Scenario: Driver accepts ride assignment
    Given I am authenticated as driver with ID 10
    And I have been assigned ride 555
    When I accept the ride assignment
    Then the response status should be 200
    And the ride status should be "Accepted"
    And the client should be notified

  Scenario: Driver rejects ride assignment
    Given I am authenticated as driver with ID 10
    And I have been assigned ride 666
    When I reject the ride assignment with reason "Traffic jam"
    Then the response status should be 200
    And the ride should be unassigned
    And the dispatcher should be notified

  Scenario: Get driver's current rides
    Given I am authenticated as driver with ID 11
    And I have active rides assigned to me
    When I send a GET request to "/api/v2/drivers/11/rides/current"
    Then the response status should be 200
    And the response should contain my active rides

  Scenario: Driver reports location update
    Given I am authenticated as driver with ID 10
    And I am on an active ride
    When I send location update with:
      | latitude  | 50.4501 |
      | longitude | 30.5234 |
      | heading   | 45.0    |
    Then the response status should be 200
    And the location should be updated
    And the client should receive location update