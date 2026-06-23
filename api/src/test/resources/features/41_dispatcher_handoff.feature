@api
Feature: Dispatcher Close and Hand-Off Ride
  As a dispatcher
  I want to close unassigned rides with a reason and hand them off to external drivers
  So that the dispatch workflow handles external partners correctly

  Background:
    Given the API is running

  # ── Cross-tenant cancel isolation ─────────────────────────────────────────

  Scenario: Dispatcher cannot cancel a ride from another company
    # Dispatcher of company B (valid-token-b) tries to cancel a company-A ride
    # (22222222... belongs to testCompanyId1). The service must reject with 403.
    Given I am authenticated as a dispatcher for company B
    When I send a PUT request to "/api/rides/22222222-2222-2222-2222-222222222222/cancel" with body:
      """
      {"reason":"driver_unavailable"}
      """
    Then the response status should be 403

  # ── Hand-off happy path ───────────────────────────────────────────────────

  Scenario: Dispatcher hands off a Requested ride to an external driver
    # 66666666... is seeded as Requested (testRideRequested2, companyId = testCompanyId1).
    # The step creates a partner company + external driver then issues PUT hand-off.
    Given I am authenticated as a dispatcher
    When I hand off ride "66666666-6666-6666-6666-666666666666" to a new external driver as dispatcher
    Then the response status should be 200
    And the response should contain "HandedOff"

  # ── Hand-off guard — already-assigned ride ────────────────────────────────

  Scenario: Dispatcher cannot hand off a ride that is already Assigned
    # Ride 11111111... is seeded as Assigned; canBeHandedOff returns false for non-Requested rides.
    Given I am authenticated as a dispatcher
    When I hand off ride "11111111-1111-1111-1111-111111111111" to a new external driver as dispatcher
    Then the response status should be 409
