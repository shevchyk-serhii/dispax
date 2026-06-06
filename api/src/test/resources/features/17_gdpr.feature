@api
Feature: GDPR Compliance
  As a user
  I want to manage my data consent and request data export or deletion
  So that my privacy rights are respected

  Background:
    Given the API is running

  Scenario: Get GDPR consents
    Given I am authenticated as a client
    When I send a GET request to "/api/gdpr/consents"
    Then the response status should be 200
    And the response should contain consent details

  Scenario: Update GDPR consents
    Given I am authenticated as a client
    When I send a PUT request to "/api/gdpr/consents" with body:
      """
      {"consentType":"Marketing","granted":true,"ipAddress":"127.0.0.1"}
      """
    Then the response status should be 200
    And the response should contain consent details

  Scenario: Export personal data
    Given I am authenticated as a client
    When I send a GET request to "/api/gdpr/export"
    Then the response status should be 200
    And the response should contain exported data details

  Scenario: Submit data deletion request
    Given I am authenticated as a client
    When I send a POST request to "/api/gdpr/deletion-request" with body:
      """
      {"reason":"No longer using the service"}
      """
    Then the response status should be 201
    And the response should contain deletion request details

  Scenario: Get deletion requests as admin
    Given I am authenticated as an admin
    When I send a GET request to "/api/gdpr/requests"
    Then the response status should be 200
    And the response should contain deletion request entries

  Scenario: Get GDPR consents without authentication
    When I send a GET request to "/api/gdpr/consents" without authentication
    Then the response status should be 401
