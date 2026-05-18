@api
Feature: Extended Ride Operations
  As a dispatcher, driver or client
  I want to perform advanced ride operations
  So that the full ride lifecycle is covered

  Background:
    Given the API is running

  Scenario: Get all rides
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/rides"
    Then the response status should be 200
    And the response should contain ride entries

  Scenario: Get pending rides
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/rides/pending"
    Then the response status should be 200
    And the response should contain ride entries

  Scenario: Get unpaid rides
    Given I am authenticated as an admin
    When I send a GET request to "/api/rides/unpaid"
    Then the response status should be 200
    And the response should contain ride entries

  Scenario: Get rides by driver
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/rides/driver/22222222-2222-2222-2222-222222222222"
    Then the response status should be 200
    And the response should contain ride entries

  Scenario: Get rides by client
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/rides/client/11111111-1111-1111-1111-111111111111"
    Then the response status should be 200
    And the response should contain ride entries

  Scenario: Update ride status
    Given I am authenticated as a driver
    When I send a PUT request to "/api/rides/11111111-1111-1111-1111-111111111111/status" with body:
      """
      {"status":"InProgress"}
      """
    Then the response status should be 200
    And the response should contain ride details

  Scenario: Assign driver to ride
    Given I am authenticated as a dispatcher
    When I send a PUT request to "/api/rides/11111111-1111-1111-1111-111111111111/assign-driver" with body:
      """
      {"driverId":"22222222-2222-2222-2222-222222222222"}
      """
    Then the response status should be 200
    And the response should contain ride details

  Scenario: Reassign driver on ride
    Given I am authenticated as a dispatcher
    When I send a PUT request to "/api/rides/11111111-1111-1111-1111-111111111111/reassign-driver" with body:
      """
      {"driverId":"33333333-3333-3333-3333-333333333333","reason":"Original driver unavailable"}
      """
    Then the response status should be 200
    And the response should contain ride details

  Scenario: Cancel a ride
    Given I am authenticated as a dispatcher
    When I send a PUT request to "/api/rides/11111111-1111-1111-1111-111111111111/cancel" with body:
      """
      {"reason":"Client request"}
      """
    Then the response status should be 200
    And the response should contain ride details

  Scenario: Update ride payment
    Given I am authenticated as an admin
    When I send a PUT request to "/api/rides/11111111-1111-1111-1111-111111111111/payment" with body:
      """
      {"amount":45.00,"method":"Card","paid":true}
      """
    Then the response status should be 200
    And the response should contain ride details

  Scenario: Add airport timing to ride
    Given I am authenticated as a dispatcher
    When I send a POST request to "/api/rides/11111111-1111-1111-1111-111111111111/airport-timing" with body:
      """
      {"flightNumber":"LH1234","scheduledArrival":"2026-06-01T08:00:00Z"}
      """
    Then the response status should be 200
    And the response should contain ride details

  Scenario: Post client location for ride
    Given I am authenticated as a client
    When I send a POST request to "/api/rides/11111111-1111-1111-1111-111111111111/client-location" with body:
      """
      {"latitude":48.1351,"longitude":11.5820}
      """
    Then the response status should be 200

  Scenario: Get ride location history
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/rides/11111111-1111-1111-1111-111111111111/locations"
    Then the response status should be 200
    And the response should contain location entries

  Scenario: Send chat message in ride
    Given I am authenticated as a client
    When I send a POST request to "/api/rides/11111111-1111-1111-1111-111111111111/chat" with body:
      """
      {"message":"I am at the entrance"}
      """
    Then the response status should be 201
    And the response should contain chat message details

  Scenario: Get ride chat messages
    Given I am authenticated as a client
    When I send a GET request to "/api/rides/11111111-1111-1111-1111-111111111111/chat"
    Then the response status should be 200
    And the response should contain chat message entries

  Scenario: Rate a completed ride
    Given I am authenticated as a client
    When I send a POST request to "/api/rides/11111111-1111-1111-1111-111111111111/rate" with body:
      """
      {"rating":5,"comment":"Excellent service"}
      """
    Then the response status should be 201
    And the response should contain rating details

  Scenario: Get ride rating
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/rides/11111111-1111-1111-1111-111111111111/rating"
    Then the response status should be 200
    And the response should contain rating details

  Scenario: Get rides without authentication
    When I send a GET request to "/api/rides" without authentication
    Then the response status should be 401
