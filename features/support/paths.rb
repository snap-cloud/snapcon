# TL;DR: YOU SHOULD DELETE THIS FILE
#
# This file is used by web_steps.rb, which you should also delete
#
# You have been warned
module NavigationHelpers
  # Maps a name to a path. Used by the
  #
  #   When /^I go to (.+)$/ do |page_name|
  #
  # step definition in web_steps.rb
  #
  def path_to(page_name)
    case page_name

    when /^the home\s?page$/
      '/'

    # Add more mappings here.
    # Here is an example that pulls values out of the Regexp:
    #
    #   when /^(.*)'s profile page$/i
    #     user_profile_path(User.find_by_login($1))
    when /^the "(.*)" conference's schedule page$/
      conference = Conference.find_by(short_title: Regexp.last_match(1))
      conference_schedule_path(conference)
    when /^the login page$/
      new_user_session_path
    when /^the admin's conference page/
      admin_conferences_path
    when /^the "(.*)"'s edit profile path/
      user = User.find_by(username: Regexp.last_match(1))
      edit_user_path(user.id)
    when /^the "(.*)" conference's all events page/
      events_conference_schedule_path(Regexp.last_match(1))
    when /^the "(.*)" conference's happening now page/
      happening_now_conference_schedule_path(Regexp.last_match(1))
    else
      begin
        page_name =~ /^the (.*) page$/
        path_components = Regexp.last_match(1).split(/\s+/)
        send(path_components.push('path').join('_').to_sym)
      rescue NoMethodError, ArgumentError
        raise "Can't find mapping from \"#{page_name}\" to a path.\n" \
              "Now, go and add a mapping in #{__FILE__}"
      end
    end
  end
end

World(NavigationHelpers)
