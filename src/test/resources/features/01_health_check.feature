@api
Feature: Health Check API
  As a system administrator
  I want to check the health of the API
  So that I can monitor system status

  Scenario: Health check endpoint returns OK
    Given the API is running
    When I send a GET request to "/health"
    Then the response status should be 200
    And the response should contain "Der Oktopus Modular API - OK"

  Scenario: Ride service health check
    Given the API is running
    When I send a GET request to "/api/v2/health"
    Then the response status should be 200
    And the response should contain service status information