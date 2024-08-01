Feature: User can view all events in the conference

Background:
    Given I have my test database setup

Scenario: Display events using the conference's timezone
    Given I am on the "osemdemo" conference's all events page
    Then I should see "Program for Open Source Event Manager Demo Conference"
    And I should see "All events are currently displayed in PDT (UTC -7)."
    And I should see the following data: 8:00 am - 8:30 am PDT, 8:30 am - 9:00 am PDT
    And I should see the following data in order: Dates, 2014-05-03, 2014-05-04, 2014-05-05, 2014-05-06, 2014-05-07, Unscheduled
    And I should see the following data in order: 2014-05-03, 08:00 AM PDT, first_scheduled_event, 8:00 am, first_scheduled_subevent, 08:30 AM PDT, multiple_speaker_event

Scenario: Display events using the user's timezone
    Given I sign in with username "admin" and password "password123"
    And I am on the "osemdemo" conference's all events page
    Then I should see "Program for Open Source Event Manager Demo Conference"
    And I should see "All events are currently displayed in AEST (UTC 10)."
    And I should see the following data: 1:00 am - 1:30 am AEST, 1:30 am - 2:00 am AEST
    And I should see the following data in order: Dates, 2014-05-04, 2014-05-05, 2014-05-06, 2014-05-07, 2014-05-08, Unscheduled
    And I should see the following data in order: 2014-05-04, 01:00 AM AEST, first_scheduled_event, 1:00 am, first_scheduled_subevent, 01:30 AM AEST, multiple_speaker_event
