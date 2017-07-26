require 'spec_helper'

describe JobEdge, type: :model do
  it { should validate_presence_of(:dependent_id) }
  it { should validate_presence_of(:dependency_id) }

  it { should belong_to(:dependency).class_name('Job') }
  it { should belong_to(:dependent).class_name('Job') }
end

