# Frontend Ride Management Expectations  
# Tests for ride API endpoints that Flutter frontend expects to exist
@api @frontend-rides
Feature: Frontend Ride Management API Expectations

  Background:
    Given the API server is running at "http://127.0.0.1:8080"
    And I am authenticated as a client with ID 1

  @rides @list
  Scenario: Frontend expects to get list of all rides
    When I make a GET request to "/api/rides"
    Then the response status should be 200
    And the response should contain a JSON array of rides
    And each ride should have required fields:
      | id | clientId | status | pickupLocation | destination | pickupTime |

  @rides @get @single
  Scenario: Frontend expects to get single ride by ID
    When I make a GET request to "/api/rides/1"
    Then the response status should be 200
    And the response should contain JSON ride with ID 1
    And the ride should have all required fields:
      | id | clientId | status | pickupLocation | destination | pickupTime | driverId |

  @rides @get @notfound
  Scenario: Frontend expects 404 for non-existent ride
    When I make a GET request to "/api/rides/999"
    Then the response status should be 404

  @rides @create
  Scenario: Frontend expects to create new ride
    When I make a POST request to "/api/rides" with JSON:
      """
      {
        "clientId": 1,
        "pickupLocation": "Airport Terminal 1",
        "destination": "Hotel Paradise", 
        "pickupTime": "2025-12-15T10:30:00Z",
        "status": "REQUESTED",
        "passengerCount": 2,
        "flightNumber": "LH1234",
        "specialRequirements": "Child seat needed"
      }
      """
    Then the response status should be 201
    And the response should contain JSON ride with:
      | clientId | 1 |
      | status | REQUESTED |
      | pickupLocation | Airport Terminal 1 |
      | destination | Hotel Paradise |

  @rides @update
  Scenario: Frontend expects to update existing ride
    When I make a PUT request to "/api/rides/1" with JSON:
      """
      {
        "clientId": 1,
        "pickupLocation": "Updated Location",
        "destination": "Updated Destination",
        "pickupTime": "2025-12-15T11:00:00Z", 
        "status": "CONFIRMED",
        "passengerCount": 3
      }
      """
    Then the response status should be 200
    And the response should contain JSON ride with:
      | pickupLocation | Updated Location |
      | destination | Updated Destination |
      | status | CONFIRMED |

  @rides @delete
  Scenario: Frontend expects to delete ride
    When I make a DELETE request to "/api/rides/1"
    Then the response status should be 204
    And the response should be empty

  @rides @status @update  
  Scenario: Frontend expects to update ride status
    When I make a PATCH request to "/api/rides/1/status" with JSON:
      """
      {
        "status": "IN_PROGRESS"
      }
      """
    Then the response status should be 200
    And the response should contain JSON:
      """
      {
        "success": true,
        "status": "IN_PROGRESS"
      }
      """

  @rides @driver @assign
  Scenario: Frontend expects to assign driver to ride
    When I make a PUT request to "/api/rides/1/assign-driver" with JSON:
      """
      {
        "driverId": 10
      }
      """
    Then the response status should be 200
    And the response should contain JSON ride with:
      | driverId | 10 |
      | status | ASSIGNED |

  @rides @driver @unassign
  Scenario: Frontend expects to unassign driver from ride  
    When I make a PUT request to "/api/rides/1/unassign-driver"
    Then the response status should be 200
    And the response should contain JSON ride with:
      | driverId | null |
      | status | REQUESTED |

  @rides @user @filter
  Scenario: Frontend expects to get rides filtered by user
    When I make a GET request to "/api/rides?clientId=1"
    Then the response status should be 200
    And the response should contain a JSON array of rides
    And all rides should have clientId 1

  @rides @driver @filter  
  Scenario: Frontend expects to get rides filtered by driver
    When I make a GET request to "/api/rides?driverId=10"
    Then the response status should be 200
    And the response should contain a JSON array of rides
    And all rides should have driverId 10

  @rides @status @filter
  Scenario: Frontend expects to get rides filtered by status
    When I make a GET request to "/api/rides?status=REQUESTED"
    Then the response status should be 200
    And the response should contain a JSON array of rides
    And all rides should have status "REQUESTED"

  @rides @validation @error
  Scenario: Frontend expects 400 for invalid ride data
    When I make a POST request to "/api/rides" with JSON:
      """
      {
        "clientId": "not-a-number",
        "pickupLocation": "",
        "destination": "",
        "pickupTime": "invalid-date"
      }
      """
    Then the response status should be 400
    And the response should contain validation errors