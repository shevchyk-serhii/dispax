Feature: Ride Management
  As a user of the Oktopus platform
  I want to manage rides (create, view, update status)
  So that I can book and track transportation services

  Background:
    Given the system is running
    And I have a valid authentication token
    And I am logged in as a client

  Scenario: Create a new ride successfully
    Given I want to create a ride from "Munich Airport Terminal 2" to "Marienplatz, Munich"
    And the pickup time is scheduled for tomorrow at 10:00 AM
    And I add a note "Please wait at arrivals hall"
    When I submit the ride creation request
    Then the ride should be created successfully
    And the ride status should be "Requested"
    And the response should contain the ride ID
    And the pickup location should be "Munich Airport Terminal 2"
    And the dropoff location should be "Marienplatz, Munich"

  Scenario: Create an airport transfer ride
    Given I want to create an airport transfer ride
    And the pickup location is "Munich Hotel, Maximilianstrasse 15"
    And the dropoff location is "Munich Airport Terminal 1"
    And the airport code is "MUC"
    And the flight number is "LH2453"
    And the pickup time is scheduled for today at 3:00 PM
    When I submit the ride creation request
    Then the ride should be created successfully
    And the ride should be marked as an airport transfer
    And the airport code should be "MUC"
    And the flight number should be "LH2453"

  Scenario: Fail to create ride with invalid data
    Given I want to create a ride with invalid data
    And the pickup location is empty
    And the dropoff location is "Some destination"
    When I submit the ride creation request
    Then the ride creation should fail
    And I should receive a validation error
    And the error message should contain "Pickup location cannot be empty"

  Scenario: View my rides as a client
    Given I have created 3 rides in the system
    When I request to view my rides
    Then I should see 3 rides in the response
    And all rides should belong to me
    And the rides should be ordered by creation time (newest first)

  Scenario: View specific ride details
    Given I have created a ride with ID 123
    When I request ride details for ride ID 123
    Then I should see the complete ride information
    And the ride should belong to me
    And the response should include pickup and dropoff locations

  Scenario: Cannot access other user's rides
    Given another user has created a ride with ID 456
    When I try to access ride ID 456
    Then I should receive a "Forbidden" response
    And the error message should indicate insufficient permissions

  Scenario: Update ride status as driver
    Given I am logged in as a driver
    And there is an assigned ride with ID 789
    And I am the assigned driver for this ride
    When I update the ride status to "InProgress"
    Then the ride status should be updated to "InProgress"
    And the start time should be set to current time

  Scenario: Cannot update ride with invalid status transition
    Given I am logged in as a driver
    And there is a ride with status "Requested"
    When I try to update the ride status to "Completed"
    Then the status update should fail
    And I should receive a validation error about invalid status transition

  Scenario: Create ride with scheduled time in the past fails
    Given I want to create a ride from "Location A" to "Location B"
    And the pickup time is scheduled for yesterday
    When I submit the ride creation request
    Then the ride creation should fail
    And the error message should contain "Scheduled time cannot be in the past"

  Scenario: Unauthorized access without token
    Given I do not have an authentication token
    When I try to create a ride
    Then I should receive an "Unauthorized" response
    And the error message should indicate missing authorization

  Scenario: Access with expired token
    Given I have an expired authentication token
    When I try to create a ride
    Then I should receive an "Unauthorized" response
    And the error message should indicate invalid or expired token