# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :click_event do
    delivery_link
    user_agent { "MyText" }
    referer { "MyText" }
    ip { "MyString" }
  end
end
