Feature: User can change time zone via a dropdown

Background:
    Given I have my test database setup

Scenario: Edit user timezone
    Given I sign in with username "admin" and password "password123"
    When I go to the "admin"'s edit profile path
    Then I should see "Edit your profile"
    When I select "Fiji" from "user[timezone]"
    And I press "Update"
    Then I should see "User was successfully updated."
    When I am on the "osemdemo" conference's all events page
    Then I should see "Program for Open Source Event Manager Demo Conference"
    And I should see "All events are currently displayed in +12 (UTC 12)"
    And I am on the "osemdemo" conference's happening now page
    Then I should see "Happening Now at Open Source Event Manager Demo Conference"
    And I should see "All events are currently displayed in +12 (UTC 12)"
