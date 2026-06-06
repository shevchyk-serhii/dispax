@api
Feature: Geofence Management
  As an administrator
  I want to manage geofences
  So that I can monitor vehicles entering and leaving zones

  Background:
    Given the API is running

  Scenario: Create a geofence
    Given I am authenticated as an admin
    When I send a POST request to "/api/geofences" with body:
      """
      {"name":"Airport Zone","geofenceType":"Airport","centerLatitude":48.3537,"centerLongitude":11.7750,"radiusMeters":1000}
      """
    Then the response status should be 201
    And the response should contain geofence details

  Scenario: Get all geofences
    Given I am authenticated as an admin
    When I send a GET request to "/api/geofences"
    Then the response status should be 200
    And the response should contain geofence entries

  Scenario: Update a geofence
    Given I am authenticated as an admin
    When I send a PUT request to "/api/geofences/11111111-1111-1111-1111-111111111111" with body:
      """
      {"name":"Airport Zone Extended","geofenceType":"Airport","centerLatitude":48.3537,"centerLongitude":11.7750,"radiusMeters":1500}
      """
    Then the response status should be 200
    And the response should contain geofence details

  Scenario: Delete a geofence
    Given I am authenticated as an admin
    When I send a DELETE request to "/api/geofences/11111111-1111-1111-1111-111111111111"
    Then the response status should be 204

  Scenario: Get geofence alerts
    Given I am authenticated as an admin
    When I send a GET request to "/api/geofences/alerts"
    Then the response status should be 200
    And the response should contain geofence alert entries

  Scenario: Get geofence alerts for specific driver
    Given I am authenticated as an admin
    When I send a GET request to "/api/geofences/alerts/driver/11111111-1111-1111-1111-111111111111"
    Then the response status should be 200
    And the response should contain geofence alert entries

  Scenario: Get geofences without authentication
    When I send a GET request to "/api/geofences" without authentication
    Then the response status should be 401
