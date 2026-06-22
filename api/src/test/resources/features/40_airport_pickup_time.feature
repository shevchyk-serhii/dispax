@api
Feature: Airport departure ride automatic pickup time calculation
  As a dispatcher creating an airport departure ride
  I want the backend to compute the pickup time automatically from the flight departure time
  So that passengers are picked up with enough time to check in and board their flight

  Background:
    Given the API is running

  # Scenario 1: global defaults → pickup is computed automatically
  # flight departs 2030-12-10T15:00:00Z, global defaults: buffer=15, checkIn=60
  # no flightTime resolved through HERE adapter (noop returns Some(10)) → total = 10+60+15 = 85 min
  # expected pickup ≈ 2030-12-10T13:35:00Z
  Scenario: Departure ride without manual pickupDateTime triggers auto-compute
    Given I am authenticated as a dispatcher
    When I send a POST request to "/api/rides" with body:
      """
      {
        "clientId": "11111111-1111-1111-1111-111111111111",
        "creatorId": "33333333-3333-3333-3333-333333333333",
        "clientName": "Test User",
        "from": {"address": "Marienplatz München"},
        "to": {"address": "Flughafen München"},
        "isAirportTransfer": true,
        "isArrival": false,
        "flightNumber": "LH001",
        "flightTime": "2030-12-10T15:00:00Z"
      }
      """
    Then the response status should be 201
    And the response should contain ride details
    And the response should contain "pickupDateTime"

  # Scenario 2: departure ride WITH explicit pickupDateTime → NOT overridden
  Scenario: Departure ride with explicit manual pickupDateTime is not overridden
    Given I am authenticated as a dispatcher
    When I send a POST request to "/api/rides" with body:
      """
      {
        "clientId": "11111111-1111-1111-1111-111111111111",
        "creatorId": "33333333-3333-3333-3333-333333333333",
        "clientName": "Test User",
        "from": {"address": "Marienplatz München"},
        "to": {"address": "Flughafen München"},
        "isAirportTransfer": true,
        "isArrival": false,
        "flightNumber": "LH002",
        "flightTime": "2030-12-10T15:00:00Z",
        "pickupDateTime": "2030-12-10T12:00:00Z"
      }
      """
    Then the response status should be 201
    And the response should contain "2030-12-10T12:00:00Z"

  # Scenario 3: arrival ride → pickupDateTime unchanged (no auto-compute)
  Scenario: Arrival ride is never auto-computed
    Given I am authenticated as a dispatcher
    When I send a POST request to "/api/rides" with body:
      """
      {
        "clientId": "11111111-1111-1111-1111-111111111111",
        "creatorId": "33333333-3333-3333-3333-333333333333",
        "clientName": "Test User",
        "from": {"address": "Flughafen München"},
        "to": {"address": "Marienplatz München"},
        "isAirportTransfer": true,
        "isArrival": true,
        "flightNumber": "LH100",
        "flightTime": "2030-12-10T10:00:00Z",
        "pickupDateTime": "2030-12-10T11:30:00Z"
      }
      """
    Then the response status should be 201
    And the response should contain "2030-12-10T11:30:00Z"

  # Scenario 4: regular (non-airport) ride → no auto-compute
  Scenario: Regular (non-airport) ride pickupDateTime is not auto-computed
    Given I am authenticated as a dispatcher
    When I send a POST request to "/api/rides" with body:
      """
      {
        "clientId": "11111111-1111-1111-1111-111111111111",
        "creatorId": "33333333-3333-3333-3333-333333333333",
        "clientName": "Test User",
        "from": {"address": "Marienplatz München"},
        "to": {"address": "Hauptbahnhof München"},
        "isAirportTransfer": false,
        "pickupDateTime": "2030-12-10T09:00:00Z"
      }
      """
    Then the response status should be 201
    And the response should contain "2030-12-10T09:00:00Z"

  # Scenario 5: company-level override of airport timing settings is persisted
  Scenario: Company airport timing settings can be updated via settings API
    Given I am authenticated as an admin
    When I send a PUT request to "/api/company/settings" with body:
      """
      {
        "airportBufferMinutes": 20,
        "airportCheckInCloseMinutes": 45
      }
      """
    Then the response status should be 200
    And the response should contain "airportBufferMinutes"

  # Scenario 6: airport timing settings are readable after update
  Scenario: Updated airport timing settings are returned in GET company settings
    Given I am authenticated as an admin
    When I send a GET request to "/api/company/settings"
    Then the response status should be 200
    And the response should contain company settings details

  # Scenario 7: client company supports airport timing fields
  Scenario: Client company can store airport timing override fields
    Given I am authenticated as an admin
    When I send a POST request to "/api/client-companies" with body:
      """
      {
        "name": "Airport Corp",
        "email": "airport@corp.de",
        "airportBufferMinutes": 10,
        "airportCheckInCloseMinutes": 30
      }
      """
    Then the response status should be 201
    And the response should contain client company details
