# Frontend User Management Expectations
# Tests for user API endpoints that Flutter frontend expects to exist
@api @frontend-users
Feature: Frontend User Management API Expectations

  Background:
    Given the API server is running at "http://127.0.0.1:8080"
    And I am authenticated as an admin with ID 1

  @users @list
  Scenario: Frontend expects to get list of all users
    When I make a GET request to "/api/users"
    Then the response status should be 200
    And the response should contain a JSON array of users
    And each user should have required fields:
      | id | email | name | role | createdAt |

  @users @get @single
  Scenario: Frontend expects to get single user by ID
    When I make a GET request to "/api/users/1"
    Then the response status should be 200
    And the response should contain JSON user with ID 1
    And the user should have all required fields:
      | id | email | name | role | createdAt | phone | status |

  @users @get @profile
  Scenario: Frontend expects current user profile endpoint
    Given I am authenticated as a client with ID 50
    When I make a GET request to "/api/users/profile"
    Then the response status should be 200
    And the response should contain JSON user with ID 50

  @users @create
  Scenario: Frontend expects to create new user
    When I make a POST request to "/api/users" with JSON:
      """
      {
        "email": "newuser@example.com",
        "name": "New User",
        "role": "CLIENT",
        "phone": "+1234567890",
        "password": "password123"
      }
      """
    Then the response status should be 201
    And the response should contain JSON user with:
      | email | newuser@example.com |
      | name | New User |
      | role | CLIENT |
      | phone | +1234567890 |

  @users @create @duplicate
  Scenario: Frontend expects 409 for duplicate email
    When I make a POST request to "/api/users" with JSON:
      """
      {
        "email": "existing@example.com",
        "name": "Duplicate User",
        "role": "CLIENT",
        "password": "password123"
      }
      """
    Then the response status should be 409
    And the response should contain error message about duplicate email

  @users @update
  Scenario: Frontend expects to update existing user
    When I make a PUT request to "/api/users/1" with JSON:
      """
      {
        "email": "updated@example.com",
        "name": "Updated Name",
        "role": "CLIENT",
        "phone": "+9876543210",
        "status": "ACTIVE"
      }
      """
    Then the response status should be 200
    And the response should contain JSON user with:
      | email | updated@example.com |
      | name | Updated Name |
      | phone | +9876543210 |

  @users @profile @update
  Scenario: Frontend expects user to update own profile
    Given I am authenticated as a client with ID 50
    When I make a PUT request to "/api/users/profile" with JSON:
      """
      {
        "name": "Updated Profile Name",
        "phone": "+1111111111"
      }
      """
    Then the response status should be 200
    And the response should contain JSON user with:
      | id | 50 |
      | name | Updated Profile Name |
      | phone | +1111111111 |

  @users @delete
  Scenario: Frontend expects to delete user (admin only)
    When I make a DELETE request to "/api/users/999"
    Then the response status should be 204
    And the response should be empty

  @users @password @change
  Scenario: Frontend expects password change endpoint
    Given I am authenticated as a client with ID 50
    When I make a POST request to "/api/users/password/change" with JSON:
      """
      {
        "currentPassword": "oldpassword123",
        "newPassword": "newpassword456"
      }
      """
    Then the response status should be 200
    And the response should contain JSON:
      """
      {
        "success": true
      }
      """

  @users @role @filter
  Scenario: Frontend expects to get users filtered by role
    When I make a GET request to "/api/users?role=DRIVER"
    Then the response status should be 200
    And the response should contain a JSON array of users
    And all users should have role "DRIVER"

  @users @status @filter
  Scenario: Frontend expects to get users filtered by status
    When I make a GET request to "/api/users?status=ACTIVE"
    Then the response status should be 200
    And the response should contain a JSON array of users
    And all users should have status "ACTIVE"

  @users @search
  Scenario: Frontend expects to search users by name/email
    When I make a GET request to "/api/users?search=john"
    Then the response status should be 200
    And the response should contain a JSON array of users
    And users should match search term "john" in name or email

  @users @validation @error
  Scenario: Frontend expects 400 for invalid user data
    When I make a POST request to "/api/users" with JSON:
      """
      {
        "email": "not-an-email",
        "name": "",
        "role": "INVALID_ROLE",
        "phone": "123",
        "password": "short"
      }
      """
    Then the response status should be 400
    And the response should contain validation errors

  @users @authorization
  Scenario: Frontend expects 403 for unauthorized access to admin endpoints
    Given I am authenticated as a client with ID 50
    When I make a GET request to "/api/users"
    Then the response status should be 403
    And the response should contain authorization error

  @users @avatar @upload
  Scenario: Frontend expects avatar upload functionality
    Given I am authenticated as a client with ID 50
    When I make a POST request to "/api/users/avatar" with form data:
      | avatar | image-file-data |
    Then the response status should be 200
    And the response should contain JSON:
      """
      {
        "success": true,
        "avatarUrl": "https://storage.example.com/avatars/50.jpg"
      }
      """