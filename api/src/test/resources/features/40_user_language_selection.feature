@api
Feature: Per-user language preference
  As a user
  I want to set my preferred UI language in my profile
  So that the interface is shown in my language on any device

  Background:
    Given the API is running

  @language @update @profile
  Scenario: User updates their preferred language to German via profile endpoint
    Given I am authenticated as a client
    When I send a PUT request to "/api/users/profile" with body:
      """
      {"preferredLanguage":"de"}
      """
    Then the response status should be 200
    And the response should contain "preferredLanguage"

  @language @update @profile
  Scenario: User updates their preferred language to Ukrainian via profile endpoint
    Given I am authenticated as a client
    When I send a PUT request to "/api/users/profile" with body:
      """
      {"preferredLanguage":"uk"}
      """
    Then the response status should be 200
    And the response should contain "preferredLanguage"

  @language @update @profile
  Scenario: User updates their preferred language to English via profile endpoint
    Given I am authenticated as a client
    When I send a PUT request to "/api/users/profile" with body:
      """
      {"preferredLanguage":"en"}
      """
    Then the response status should be 200
    And the response should contain "preferredLanguage"

  @language @get @profile
  Scenario: GET profile returns preferredLanguage field after it was set
    Given I am authenticated as a client
    When I send a PUT request to "/api/users/profile" with body:
      """
      {"preferredLanguage":"de"}
      """
    Then the response status should be 200
    When I send a GET request to "/api/users/profile"
    Then the response status should be 200
    And the response should contain "preferredLanguage"

  @language @update @profile
  Scenario: Unsupported language code is silently ignored — update still succeeds
    Given I am authenticated as a client
    When I send a PUT request to "/api/users/profile" with body:
      """
      {"preferredLanguage":"fr"}
      """
    Then the response status should be 200

  @language @unauthorized
  Scenario: Unauthenticated request to update profile is rejected
    When I send a PUT request to "/api/users/profile" without authentication
    Then the response status should be 401
