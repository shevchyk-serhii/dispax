@api
Feature: Company Settings
  As an administrator
  I want to manage company settings and tariffs
  So that I can configure the service

  Background:
    Given the API is running

  Scenario: Get company settings
    Given I am authenticated as an admin
    When I send a GET request to "/api/company/settings"
    Then the response status should be 200
    And the response should contain company settings details

  Scenario: Update company settings
    Given I am authenticated as an admin
    When I send a PUT request to "/api/company/settings" with body:
      """
      {"companyName":"Dispax GmbH","timezone":"Europe/Berlin","currency":"EUR"}
      """
    Then the response status should be 200
    And the response should contain company settings details

  Scenario: Get company tariff
    Given I am authenticated as an admin
    When I send a GET request to "/api/company/tariff"
    Then the response status should be 200
    And the response should contain tariff details

  Scenario: Update company tariff
    Given I am authenticated as an admin
    When I send a PUT request to "/api/company/tariff" with body:
      """
      {"baseRate":2.50,"perKmRate":1.20,"minimumFare":5.00}
      """
    Then the response status should be 200
    And the response should contain tariff details

  Scenario: Get company settings without authentication
    When I send a GET request to "/api/company/settings" without authentication
    Then the response status should be 401
