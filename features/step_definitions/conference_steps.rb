Given /^I have my test database setup/ do
  execute_rake('demo_data_for_development.rake', 'data:test')
end

Given /^I sign in with username "(.*)" and password "(.*)"/ do |username, password|
  step 'I am on the login page'
  step 'I should see "Sign In"'
  step 'I fill in "' + username + '" for "user_login"'
  step 'I fill in "' + password + '" for "user_password"'
  step 'I press "Sign In"'
  step 'I should see "Signed in successfully."'
end

When /^I click on the "(.*)" link of.*"(.*)"/ do |button, data|
  click_link(button, href: vertical_schedule_conference_schedule_path(data)) if button == 'Schedule'
end

When /^I click on the "(.*)" button/ do |button|
  click_on(class: 'fc-' + button + '-button')
end

Then /^I should see the following data in order: (.*)/ do |list|
  data_list = list.split(', ')
  if data_list.length <= 1
    step "I should see \"#{list}\""
  else
    (data_list.length - 1).times do |index|
      first = data_list[index]
      second = data_list[index + 1]
      expect(page.text).to match(/.*#{first}.*#{second}.*/m)
    end
  end
end

Then /^I should see "(.*)" before "(.*)"/ do |first, second|
  expect(page.text).to match(/.*#{first}.*#{second}.*/m)
end

Then /^I should see the following data: (.*)/ do |list|
  list.split(', ').each do |text|
    step "I should see \"#{text}\""
  end
end

def execute_rake(file, task)
  require 'rake'
  rake = Rake::Application.new
  Rake.application = rake
  Rake::Task.define_task(:environment)
  load "#{Rails.root}/lib/tasks/#{file}"
  rake[task].invoke
end
