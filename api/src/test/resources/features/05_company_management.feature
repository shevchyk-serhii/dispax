@api
Feature: Company Management
  As a taxi service administrator
  I want to manage taxi companies
  So that I can organize fleet operations

  Background:
    Given the API is running
    And the following companies exist:
      | CompanyId | Name           | Email               | Phone        | Address        |
      | 100       | Oktopus Taxi   | info@oktopus.ua     | +380501234567| Kyiv, Ukraine  |
      | 101       | City Cab       | admin@citycab.com   | +380671234567| Lviv, Ukraine  |

  Scenario: Create a new company
    Given I am authenticated as an admin
    When I create a company with:
      | name    | Metro Taxi             |
      | email   | contact@metrotaxi.com  |
      | phone   | +380631234567          |
      | address | Dnipro, Ukraine        |
    Then the response status should be 201
    And the response should contain company details
    And the company should have a unique ID

  Scenario: Get company by ID
    Given I am authenticated as an admin
    When I send a GET request to "/api/v2/companies/100"
    Then the response status should be 200
    And the response should contain company details for "Oktopus Taxi"

  Scenario: Get all companies
    Given I am authenticated as an admin
    When I send a GET request to "/api/v2/companies"
    Then the response status should be 200
    And the response should contain 2 companies
    And the companies should include "Oktopus Taxi" and "City Cab"

  Scenario: Update company information
    Given I am authenticated as an admin
    And company 100 exists
    When I update company 100 with:
      | phone   | +380991234567    |
      | address | Kyiv, New Office |
    Then the response status should be 200
    And the company phone should be "+380991234567"
    And the company address should be "Kyiv, New Office"

  Scenario: Get company drivers
    Given I am authenticated as an admin
    And company 100 has assigned drivers
    When I send a GET request to "/api/v2/companies/100/drivers"
    Then the response status should be 200
    And the response should contain the list of company drivers

  Scenario: Assign driver to company
    Given I am authenticated as an admin
    And driver with ID 20 exists
    And company 100 exists
    When I assign driver 20 to company 100
    Then the response status should be 200
    And driver 20 should be assigned to company 100

  Scenario: Get company statistics
    Given I am authenticated as an admin
    And company 100 has operational data
    When I send a GET request to "/api/v2/companies/100/statistics"
    Then the response status should be 200
    And the response should contain:
      | totalDrivers   |
      | activeRides    |
      | completedRides |
      | revenue        |

  Scenario: Delete company
    Given I am authenticated as an admin
    And company 101 has no active rides
    When I send a DELETE request to "/api/v2/companies/101"
    Then the response status should be 204
    And company 101 should be deleted

  Scenario: Cannot delete company with active rides
    Given I am authenticated as an admin
    And company 100 has active rides
    When I send a DELETE request to "/api/v2/companies/100"
    Then the response status should be 400
    And the response should contain "Cannot delete company with active rides"