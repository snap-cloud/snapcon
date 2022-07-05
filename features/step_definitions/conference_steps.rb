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
  if button == 'Schedule'
    click_link(button, href: vertical_schedule_conference_schedule_path(data))
  end
end
When /^I click on the "(.*)" button/ do |button|
  click_on(class: 'fc-' + button + '-button')
end
Then /^I should have the following data in the following order: (.*)/ do |list|
  data_list = list.split(', ')
  if data_list.length <= 1
    step 'I should see ' + '"' + data_list[index] + '"'
  else
    (data_list.length - 1).times do |index|
      step 'I should see ' + '"' + data_list[index] + '"'
      page.body.index(data_list[index]).should < page.body.index(data_list[index + 1])
    end
  end
end
Then /^I should have the following data: (.*)/ do |list|
  data_list = list.split(', ')
  data_list.each do |data|
    step 'I should see ' + '"' + data + '"'
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
