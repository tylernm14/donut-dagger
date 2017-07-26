FactoryGirl.define do
  factory :job_edge do
    sequence(:workflow_id) { |n| n }
    sequence(:dependency_id) { |n| n }
    sequence(:dependent_id) { |n| n+1 }
  end
end