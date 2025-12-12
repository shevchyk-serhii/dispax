@api
Feature: Error Handling & Validation
  As a system
  I want to handle errors gracefully
  So that users receive meaningful feedback

  Background:
    Given the API is running

  Scenario: Handle malformed JSON request
    Given I am authenticated as a client
    When I send a POST request to "/api/v2/rides" with malformed JSON:
      """
      { "clientId": 1, "pickup": "Location" invalid json }
      """
    Then the response status should be 400
    And the response should contain "Invalid JSON format"

  Scenario: Handle missing required fields
    Given I am authenticated as a client
    When I create a ride request with missing required fields:
      | pickup      | Airport         |
      | destination |                 |
      | scheduledAt | invalid-date    |
    Then the response status should be 400
    And the response should contain validation errors
    And the errors should specify missing "destination"
    And the errors should specify invalid "scheduledAt" format

  Scenario: Handle invalid email format
    When I create a user with invalid email "not-an-email"
    Then the response status should be 400
    And the response should contain "Invalid email format"

  Scenario: Handle invalid phone number format
    When I create a user with invalid phone "123"
    Then the response status should be 400
    And the response should contain "Invalid phone number format"

  Scenario: Handle duplicate resource creation
    Given a user exists with email "existing@example.com"
    When I create a new user with email "existing@example.com"
    Then the response status should be 409
    And the response should contain "User already exists"

  Scenario: Handle concurrent modification
    Given a ride exists with ID 777
    And two clients attempt to modify ride 777 simultaneously
    When the second modification is submitted
    Then the response status should be 409
    And the response should contain "Resource was modified by another user"

  Scenario: Handle rate limiting
    Given I am authenticated as a user
    When I send 100 requests per minute to "/api/v2/rides"
    Then the 101st request should return status 429
    And the response should contain "Rate limit exceeded"
    And the response should include "Retry-After" header

  Scenario: Handle database connection failure
    Given the database is temporarily unavailable
    When I send a GET request to "/api/v2/rides"
    Then the response status should be 503
    And the response should contain "Service temporarily unavailable"

  Scenario: Handle invalid route parameters
    Given I am authenticated as a user
    When I send a GET request to "/api/v2/rides/invalid-id"
    Then the response status should be 400
    And the response should contain "Invalid ride ID format"

  Scenario: Handle unauthorized access to specific resource
    Given I am authenticated as client with ID 50
    And a ride exists with ID 888 belonging to client 60
    When I send a GET request to "/api/v2/rides/888"
    Then the response status should be 403
    And the response should contain "Access denied to this resource"

  Scenario: Handle internal server error gracefully
    Given an unexpected server error occurs
    When I send any request to the API
    Then the response status should be 500
    And the response should contain generic error message
    And sensitive information should not be exposed
    And the error should be logged with correlation ID

  Scenario: Handle timeout errors
    Given a long-running operation is requested
    When the operation exceeds timeout limit
    Then the response status should be 408
    And the response should contain "Request timeout"

  Scenario: Handle unsupported HTTP methods
    When I send a PATCH request to "/api/v2/health"
    Then the response status should be 405
    And the response should contain "Method not allowed"
    And the response should include allowed methods

  Scenario: Handle large payload
    Given I am authenticated as a client
    When I send a request with payload exceeding size limit
    Then the response status should be 413
    And the response should contain "Payload too large"