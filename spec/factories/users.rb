# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  affiliation            :string
#  avatar_content_type    :string
#  avatar_file_name       :string
#  avatar_file_size       :integer
#  avatar_updated_at      :datetime
#  biography              :text
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :string
#  default_currency       :string
#  email                  :string           default(""), not null
#  email_public           :boolean          default(FALSE)
#  encrypted_password     :string           default(""), not null
#  is_admin               :boolean          default(FALSE)
#  is_disabled            :boolean          default(FALSE)
#  languages              :string
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :string
#  mobile                 :string
#  name                   :string
#  nickname               :string
#  picture                :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  sign_in_count          :integer          default(0)
#  timezone               :string
#  tshirt                 :string
#  unconfirmed_email      :string
#  username               :string
#  volunteer_experience   :text
#  created_at             :datetime
#  updated_at             :datetime
#
# Indexes
#
#  index_users_on_confirmation_token    (confirmation_token) UNIQUE
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#  index_users_on_username              (username) UNIQUE
#

# It is a feature of our app that first signed up user is admin. This property
# is set in a before create callback `setup_role` in user model.
# We want to override this behavior when we create user factories. We want
# `create(:user)` to create non-admin user by default. We are enforcing it
# with `after create` blocks in following factories.
#
# Following commands won't work:
#       `create(:user, is_admin: true)`
#       `create(:admin, is_admin: false)`
#
# For a non-admin user, use: `create(:user)`
# For an admin user, use: `create(:admin)`
# For an organizer user, use `create(:organizer)`

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "example#{n}@example.com" }
    sequence(:name) { |n| "name#{n}" }
    sequence(:username) { |n| "username#{n}" }
    password { 'changeme' }
    password_confirmation { 'changeme' }
    confirmed_at { Time.now }
    biography { <<-EOS }
      Lorem ipsum dolor sit amet, consectetur adipiscing elit. Vivamus enim
      nunc, venenatis non sapien convallis, dictum suscipit purus. Vestibulum
      sed tincidunt tortor. Fusce viverra nisi nisi, quis congue dui faucibus
      nec. Sed sodales suscipit nulla, accumsan porttitor augue ultrices vel.
      Quisque cursus facilisis consequat. Etiam volutpat ligula turpis, at
      gravida.
    EOS
    last_sign_in_at { Date.today }
    is_disabled { false }

    # Called by every user creation

    after(:create) do |user|
      user.is_admin = false

      # save with bang cause we want change in DB and not just in object instance
      user.save!
    end

    factory :admin do
      # admin factory needs its own after create block or else after create
      # of user factory will override `is_admin` value.
      after(:create) do |user|
        user.is_admin = true
        user.save!
      end
    end

    factory :cfp_user do
      transient do
        resource { create(:resource) }
      end

      after :create do |user, evaluator|
        user.add_role :cfp, evaluator.resource
      end
    end

    trait :disabled do
      is_disabled { true }
    end
  end

  factory :user_xss, parent: :user do
    biography { '<div id="divInjectedElement"></div>' }
  end

  factory :organizer, parent: :user do
    transient do
      resource { create(:resource) }
    end

    after(:create) do |user, evaluator|
      user.roles << Role.find_or_create_by(name: 'organizer', resource: evaluator.resource)
      user.save!
    end
  end
end
