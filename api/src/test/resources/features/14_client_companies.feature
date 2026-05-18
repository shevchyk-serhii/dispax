@api
Feature: Client Company Management
  As an administrator
  I want to manage client companies
  So that I can organise corporate clients

  Background:
    Given the API is running

  Scenario: Get all client companies
    Given I am authenticated as an admin
    When I send a GET request to "/api/client-companies"
    Then the response status should be 200
    And the response should contain client company entries

  Scenario: Create a client company
    Given I am authenticated as an admin
    When I send a POST request to "/api/client-companies" with body:
      """
      {"name":"Acme Corp","email":"billing@acme.com","phone":"+49891234567","address":"Munich, Germany"}
      """
    Then the response status should be 201
    And the response should contain client company details

  Scenario: Get client company by ID
    Given I am authenticated as an admin
    When I send a GET request to "/api/client-companies/11111111-1111-1111-1111-111111111111"
    Then the response status should be 200
    And the response should contain client company details

  Scenario: Update client company
    Given I am authenticated as an admin
    When I send a PUT request to "/api/client-companies/11111111-1111-1111-1111-111111111111" with body:
      """
      {"name":"Acme Corp Updated","phone":"+49899876543"}
      """
    Then the response status should be 200
    And the response should contain client company details

  Scenario: Delete client company
    Given I am authenticated as an admin
    When I send a DELETE request to "/api/client-companies/11111111-1111-1111-1111-111111111111"
    Then the response status should be 204

  Scenario: Get client company members
    Given I am authenticated as an admin
    When I send a GET request to "/api/client-companies/11111111-1111-1111-1111-111111111111/members"
    Then the response status should be 200
    And the response should contain company member entries

  Scenario: Get client companies without authentication
    When I send a GET request to "/api/client-companies" without authentication
    Then the response status should be 401
