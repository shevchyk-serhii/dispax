@api
Feature: Dispatcher can also be a driver
  As a dispatcher who holds the Driver role in their roles set
  I want to be assignable to rides as a driver
  So that small companies can flexibly reuse dispatchers on the road

  Background:
    Given the API is running

  # ── Dispatcher-driver CAN be assigned to a ride ──────────────────────────────
  # A person with roles=[DISPATCHER, DRIVER] satisfies the canDrive check and
  # should be successfully assigned (ride transitions to Assigned).

  Scenario: Dispatcher with Driver role can be assigned to a Requested ride
    Given I am authenticated as a dispatcher
    When I send a PUT request to "/api/rides/d5d5d5d5-d5d5-d5d5-d5d5-d5d5d5d5d5d5/assign-driver" with body:
      """
      {"driverId":"dddddddd-dddd-dddd-dddd-dddddddddddd"}
      """
    Then the response status should be 200
    And the response should contain "Assigned"

  # ── Pure dispatcher (no Driver role) CANNOT be assigned ──────────────────────
  # A person whose roles set contains only DISPATCHER fails the canDrive guard
  # and the server returns 400 with "Person is not a driver".

  Scenario: Pure dispatcher without Driver role cannot be assigned as a driver
    Given I am authenticated as a dispatcher
    When I send a PUT request to "/api/rides/d6d6d6d6-d6d6-d6d6-d6d6-d6d6d6d6d6d6/assign-driver" with body:
      """
      {"driverId":"33333333-3333-3333-3333-333333333333"}
      """
    Then the response status should be 400
    And the response should contain "not a driver"

  # ── Unauthenticated access is blocked ────────────────────────────────────────

  Scenario: Unauthenticated assign-driver request is rejected
    When I send a PUT request to "/api/rides/d5d5d5d5-d5d5-d5d5-d5d5-d5d5d5d5d5d5/assign-driver" without authentication
    Then the response status should be 401
