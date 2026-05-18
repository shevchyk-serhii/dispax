@api
Feature: Expense Management
  As a driver or administrator
  I want to manage ride expenses
  So that costs are tracked accurately

  Background:
    Given the API is running

  Scenario: Create an expense
    Given I am authenticated as a driver
    When I send a POST request to "/api/expenses" with body:
      """
      {"rideId":"11111111-1111-1111-1111-111111111111","amount":15.50,"category":"Fuel","description":"Refuel before ride"}
      """
    Then the response status should be 201
    And the response should contain expense details

  Scenario: Get expenses list
    Given I am authenticated as an admin
    When I send a GET request to "/api/expenses"
    Then the response status should be 200
    And the response should contain expense entries

  Scenario: Delete an expense
    Given I am authenticated as an admin
    When I send a DELETE request to "/api/expenses/11111111-1111-1111-1111-111111111111"
    Then the response status should be 204

  Scenario: Get expenses without authentication
    When I send a GET request to "/api/expenses" without authentication
    Then the response status should be 401
