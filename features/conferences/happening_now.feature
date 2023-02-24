Feature: User can view all events in the conference that is happending now

Background:
    Given I have my test database setup

Scenario: Display events using the conference's timezone
    Given I am on the "osemdemo" conference's happening now page
    Then I should see "Happening Now at Open Source Event Manager Demo Conference"
    And I should see "All events are currently displayed in PDT (UTC -7)."


Scenario: Display events using the user's timezone
    Given I sign in with username "admin" and password "password123"
    And I am on the "osemdemo" conference's happening now page
    Then I should see "Happening Now at Open Source Event Manager Demo Conference"
    And I should see "All events are currently displayed in AEST (UTC 10)."
