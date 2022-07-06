Feature: User can view all events in the conference

Background:
    Given I have my test database setup

Scenario: Display events using the conference's timezone
    Given I am on the "osemdemo" conference's all events page
    Then I should see "Program for Open Source Event Manager Demo Conference"
    And I should see "All Events are currently scheduled in America/Los_Angeles."
    And I should have the following data: 8:00 am - 8:30 am PDT, 8:15 am - 8:45 am PDT, 8:30 am - 9:00 am PDT
    And I should have the following data in the following order: Dates, 2014-05-03, 2014-05-04, 2014-05-05, 2014-05-06, 2014-05-07, Unscheduled
    And I should have the following data in the following order: 2014-05-03, 08:00 PDT, first_scheduled_event, 08:15 PDT, second_scheduled_event, 8:30 PDT, multiple_speaker_event


Scenario: Display events using the user's timezone
    Given I sign in with username "admin" and password "password123"
    And I am on the "osemdemo" conference's all events page
    Then I should see "Program for Open Source Event Manager Demo Conference"
    And I should see "All Events are currently scheduled in Australia/Sydney."
    And I should have the following data: 1:00 am - 1:30 am AEST, 1:15 am - 1:45 am AEST, 1:30 am - 2:00 am AEST
    And I should have the following data in the following order: Dates, 2014-05-04, 2014-05-05, 2014-05-06, 2014-05-07, 2014-05-08, Unscheduled
    And I should have the following data in the following order: 2014-05-04, 01:00 AEST, first_scheduled_event, 01:15 AEST, second_scheduled_event, 01:30 AEST, multiple_speaker_event
