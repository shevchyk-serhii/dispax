@api
Feature: Billing Management
  As a dispatcher or administrator
  I want to manage billing companies and invoices
  So that corporate clients can be invoiced accurately

  Background:
    Given the API is running

  # ── Billing Companies ─────────────────────────────────────────────────────

  Scenario: Get all billing companies
    Given I am authenticated as an admin
    When I send a GET request to "/api/billing/companies"
    Then the response status should be 200
    And the response should contain client company entries

  Scenario: Create a billing company
    Given I am authenticated as an admin
    When I send a POST request to "/api/billing/companies" with body:
      """
      {"name":"BMW AG","email":"billing@bmw.de","phone":"+4989382-0","address":"Petuelring 130, 80788 München","vatId":"DE129273380"}
      """
    Then the response status should be 201
    And the response should contain client company details

  Scenario: Update a billing company
    Given I am authenticated as an admin
    When I send a PUT request to "/api/billing/companies/11111111-1111-1111-1111-111111111111" with body:
      """
      {"name":"BMW AG Updated","phone":"+4989382-1234"}
      """
    Then the response status should be 200
    And the response should contain client company details

  Scenario: Get billing companies without authentication
    When I send a GET request to "/api/billing/companies" without authentication
    Then the response status should be 401

  Scenario: Create billing company as secretary is forbidden
    Given I am authenticated as a secretary
    When I send a POST request to "/api/billing/companies" with body:
      """
      {"name":"Unauthorized Corp","email":"test@test.de"}
      """
    Then the response status should be 403

  # ── Invoices ──────────────────────────────────────────────────────────────

  Scenario: Get all invoices
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/billing/invoices"
    Then the response status should be 200
    And the response should contain ride entries

  Scenario: Create an invoice
    Given I am authenticated as a dispatcher
    When I send a POST request to "/api/billing/invoices" with body:
      """
      {"clientCompanyId":"11111111-1111-1111-1111-111111111111","periodFrom":"2026-06-01","periodTo":"2026-06-30","notes":"June 2026"}
      """
    Then the response status should be 201
    And the response should contain ride details

  Scenario: Get invoice by ID
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/billing/invoices/11111111-1111-1111-1111-111111111111"
    Then the response status should be 200
    And the response should contain ride details

  Scenario: Auto-fill invoice from completed rides
    Given I am authenticated as a dispatcher
    When I send a POST request to "/api/billing/invoices/11111111-1111-1111-1111-111111111111/auto-fill" with body:
      """
      {}
      """
    Then the response status should be 409

  Scenario: Download invoice as PDF
    Given I am authenticated as a dispatcher
    When I send a GET request to "/api/billing/invoices/11111111-1111-1111-1111-111111111111/pdf"
    Then the response status should be 200

  Scenario: Send invoice by email
    Given I am authenticated as a dispatcher
    When I send a POST request to "/api/billing/invoices/11111111-1111-1111-1111-111111111111/send" with body:
      """
      {}
      """
    Then the response status should be 409

  Scenario: Mark invoice as paid
    Given I am authenticated as a dispatcher
    When I send a POST request to "/api/billing/invoices/11111111-1111-1111-1111-111111111111/pay" with body:
      """
      {"paidAt":"2026-06-15T10:00:00Z","method":"BankTransfer"}
      """
    Then the response status should be 200
    And the response should contain ride details

  Scenario: Delete an invoice
    Given I am authenticated as an admin
    When I send a DELETE request to "/api/billing/invoices/11111111-1111-1111-1111-111111111111"
    Then the response status should be 409

  Scenario: Get invoices without authentication
    When I send a GET request to "/api/billing/invoices" without authentication
    Then the response status should be 401

  Scenario: Create invoice as driver is forbidden
    Given I am authenticated as a driver
    When I send a POST request to "/api/billing/invoices" with body:
      """
      {"clientCompanyId":"11111111-1111-1111-1111-111111111111","periodFrom":"2026-06-01","periodTo":"2026-06-30"}
      """
    Then the response status should be 403

  # Delete billing company last to avoid breaking invoice scenarios
  Scenario: Delete a billing company
    Given I am authenticated as an admin
    When I send a DELETE request to "/api/billing/companies/11111111-1111-1111-1111-111111111111"
    Then the response status should be 204
