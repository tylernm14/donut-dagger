FactoryGirl.define do
  factory :job do
    uuid { SecureRandom.uuid }
    workflow
    name { 'apple' }
    status { :running }
    description { {
        'name': 'apple',
        'image': 'timer:mine',
        'cmd': '/timer.rb',
        'args': ['30s']
    } }
  end

  factory :job_no_workflow_definition, class: Job do
    uuid { SecureRandom.uuid }
    workflow { create(:workflow_empty_definition) }
    name { 'apple' }
    status { :running }
    description { {
        'name': 'apple',
        'image': 'timer:mine',
        'cmd': '/timer.rb',
        'args': ['30s']
    } }
  end

end
