FactoryGirl.define do
  factory :workflow do
    uuid { SecureRandom.uuid }
    status { :queued }
    parallelism { 1 }
    definition
    factory :workflow_empty_definition, class: Workflow do
      definition { create(:definition_empty_data) }
    end
    factory :workflow_bad_definition, class: Workflow do
      definition { create(:definition_bad_data) }
    end
    factory :workflow_multi_root_definition, class: Workflow do
      definition { create(:definition_multi_root) }
    end
  end
end
