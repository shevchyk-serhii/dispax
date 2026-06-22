@api
Feature: Ride price editing and bulk rides by driver
  As a dispatcher or driver
  I want to set the final price on a ride and query rides for multiple drivers
  So that pricing is authoritative and the calendar view can show all assigned rides

  Background:
    Given the API is running

  # ── PUT /api/rides/{rideId}/price ─────────────────────────────────────────

  Scenario: Dispatcher sets a ride's final price
    Given I am authenticated as a dispatcher
    When I send a PUT request to "/api/rides/44444444-4444-4444-4444-444444444444/price" with body:
      """
      {"price":42.50}
      """
    Then the response status should be 200
    And the response should contain "price"

  Scenario: Driver sets price on a ride assigned to them
    # Ride 11111... is Assigned to driver 10101... (valid-token-10)
    Given I am authenticated as a driver with ID 10
    When I send a PUT request to "/api/rides/11111111-1111-1111-1111-111111111111/price" with body:
      """
      {"price":25.00}
      """
    Then the response status should be 200
    And the response should contain "price"

  Scenario: Driver tries to set price on another driver's ride — forbidden
    # Ride 11111... belongs to driver 10101...; driver 50505... is a client, not a driver, but
    # here we use driver role to test driver-ownership check: driver 33333... (dispatcher token
    # has dispatcher role; we use a client authenticated as driver to prove 403 on wrong driver).
    # valid-token-1 is a Client; we simulate a driver token for a non-assigned driver.
    Given I am authenticated as a driver with ID 50
    When I send a PUT request to "/api/rides/11111111-1111-1111-1111-111111111111/price" with body:
      """
      {"price":30.00}
      """
    Then the response status should be 403

  Scenario: Setting price with a rideId from another company — forbidden
    # Dispatcher of company B (valid-token-b) tries to set price on a company-A ride.
    Given I am authenticated as a dispatcher for company B
    When I send a PUT request to "/api/rides/11111111-1111-1111-1111-111111111111/price" with body:
      """
      {"price":50.00}
      """
    Then the response status should be 403

  Scenario: Negative price is rejected with 400
    Given I am authenticated as a dispatcher
    When I send a PUT request to "/api/rides/44444444-4444-4444-4444-444444444444/price" with body:
      """
      {"price":-10.00}
      """
    Then the response status should be 400

  Scenario: Setting price requires authentication
    When I send a PUT request to "/api/rides/44444444-4444-4444-4444-444444444444/price" without authentication
    Then the response status should be 401

  # ── GET /api/rides/by-drivers ─────────────────────────────────────────────

  Scenario: Dispatcher fetches rides for a driver — returns list
    # Driver 10101... (22222222-2222-2222-2222-222222222222... is the UUID used by valid-token-10)
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/rides/by-drivers?driverIds=10101010-1010-1010-1010-101010101010"
    Then the response status should be 200
    And the response should contain ride entries

  Scenario: Driver fetches their own rides via bulk endpoint
    Given I am authenticated as a driver with ID 10
    When I send a GET request to "/api/rides/by-drivers?driverIds=10101010-1010-1010-1010-101010101010"
    Then the response status should be 200

  Scenario: Foreign-company driverId yields no rides — no data leak
    # Company-B dispatcher queries a company-A driver: must receive an empty list, not a 403,
    # to avoid leaking whether the driver exists.
    Given I am authenticated as a dispatcher for company B
    When I send a GET request to "/api/rides/by-drivers?driverIds=10101010-1010-1010-1010-101010101010"
    Then the response status should be 200
    And the response body should be an empty JSON array

  Scenario: Malformed date in 'from' parameter returns 400
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/rides/by-drivers?driverIds=10101010-1010-1010-1010-101010101010&from=not-a-date"
    Then the response status should be 400

  Scenario: Bulk endpoint requires authentication
    When I send a GET request to "/api/rides/by-drivers?driverIds=10101010-1010-1010-1010-101010101010" without authentication
    Then the response status should be 401

  Scenario: Client role cannot access bulk-by-drivers endpoint — forbidden
    Given I am authenticated as a client
    When I send a GET request to "/api/rides/by-drivers?driverIds=10101010-1010-1010-1010-101010101010"
    Then the response status should be 403
