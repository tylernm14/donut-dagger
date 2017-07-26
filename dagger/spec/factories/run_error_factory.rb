FactoryGirl.define do
  factory :run_error do

    sequence(:title) { |n| "ERROR-#{n}" }
    status { '500' }

  end
end