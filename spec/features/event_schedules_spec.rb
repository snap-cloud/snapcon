require 'spec_helper'

describe EventSchedule, :js do
  Timecop.return
  let(:test_date) { Time.current }
  let!(:conference) do
    create(:full_conference, start_date: test_date - 1.hour, end_date: test_date + 5.days, start_hour: 0, end_hour: 24)
  end
  let!(:program) { conference.program }
  let!(:selected_schedule) { create(:schedule, program: program) }
  let!(:scheduled_event_early) do
    program.update!(selected_schedule: selected_schedule)
    create(:event, program: program, state: 'confirmed', abstract: '`markdown`')
  end
  let!(:event_schedule_early) do
    create(:event_schedule, event: scheduled_event_early, schedule: selected_schedule,
   start_time: test_date - 1.hours)
  end
  let!(:scheduled_event_mid) do
    program.update!(selected_schedule: selected_schedule)
    create(:event, program: program, state: 'confirmed')
  end
  let!(:event_schedule_mid) do
    create(:event_schedule, event: scheduled_event_mid, schedule: selected_schedule,
   start_time: test_date)
  end
  let!(:scheduled_event_late) do
    program.update!(selected_schedule: selected_schedule)
    create(:event, program: program, state: 'confirmed')
  end
  let!(:event_schedule_late) do
    create(:event_schedule, event: scheduled_event_late, schedule: selected_schedule,
   start_time: test_date + 1.hours)
  end

  before do
    login_as(create(:user), scope: :user)
    visit events_conference_schedule_path(conference_id: conference.short_title, favourites: false)
  end

  it 'jumps to the closest event' do
    find('#current-event-btn').click
    highlighted_element = page.find('.highlighted', visible: true, wait: 1)
    expect(highlighted_element[:id]).to include("event_#{scheduled_event_mid.id}")
  end
end
