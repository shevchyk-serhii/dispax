@api
Feature: Notification System
  As a taxi service
  I want to send notifications to users
  So that they stay informed about ride status and updates

  Background:
    Given the API is running
    And the notification system is active

  Scenario: Send ride assignment notification to driver
    Given driver with ID 30 exists
    And a ride assignment is created for driver 30
    When the system sends a ride assignment notification
    Then the notification should be sent to driver 30
    And the notification type should be "RideAssignment"
    And the notification should contain ride details

  Scenario: Send ride status update to client
    Given client with ID 40 exists
    And client 40 has an active ride 500
    When the ride status changes to "InProgress"
    Then the system should send a notification to client 40
    And the notification should contain the new status "InProgress"
    And the notification should include estimated arrival time

  Scenario: Send driver arrival notification
    Given client with ID 41 exists
    And driver with ID 31 is assigned to client 41's ride
    When driver 31 arrives at pickup location
    Then the system should send arrival notification to client 41
    And the notification should contain driver details
    And the notification should include vehicle information

  Scenario: Send ride completion notification
    Given client with ID 42 exists
    And client 42 has a ride that just completed
    When the ride is marked as completed
    Then the system should send completion notification to client 42
    And the notification should contain:
      | totalFare     |
      | rideDuration  |
      | ratingRequest |

  Scenario: Send emergency notification
    Given driver with ID 32 exists
    And driver 32 activates emergency button
    When the emergency notification is triggered
    Then the system should send emergency alert to dispatch
    And the notification priority should be "High"
    And the notification should include driver location

  Scenario: Send promotional notification
    Given client with ID 43 exists
    And a promotional campaign is active
    When the system sends promotional notifications
    Then client 43 should receive the promotional notification
    And the notification should contain discount information

  Scenario: Notification delivery confirmation
    Given a notification was sent to user 44
    When the notification is delivered successfully
    Then the delivery status should be marked as "Delivered"
    And the delivery timestamp should be recorded

  Scenario: Failed notification handling
    Given a notification failed to deliver to user 45
    When the notification delivery fails
    Then the system should retry delivery
    And the failure should be logged
    And an alert should be sent to system administrators

  Scenario: User notification preferences
    Given user with ID 46 has notification preferences
    And user 46 has disabled SMS notifications
    When a notification is sent to user 46
    Then SMS notifications should be skipped
    And only enabled notification channels should be used

  Scenario: Bulk notification sending
    Given there are 100 active drivers
    And a system-wide announcement needs to be sent
    When the bulk notification is triggered
    Then all 100 drivers should receive the notification
    And the system should track delivery status for each notification