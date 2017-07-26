require 'spec_helper'

describe Workflow, type: :model do

  it { should validate_presence_of(:status) }

  it { should define_enum_for(:status).with([:bootstrap, :queued, :running, :done, :failed, :dead, :terminated]) }
  it { should have_many(:jobs).dependent(:destroy) }

  before do
    Workflow.destroy_all
    #allow(StartWorkflowWorker).to receive(:perform_async).with(any_args)
    # Dont create the initial jobs in the dag of our factory workflow
    allow(CreateDagJobs).to receive(:call).with(any_args)
    @uuid = SecureRandom.uuid
    @one = create(:workflow, uuid: @uuid, user_oauth_id: 123, created_at: 2.days.ago)
    @two = create(:workflow, user_oauth_id: 789, created_at: 4.days.ago)
    @three = create(:workflow, created_at: 10.days.ago)
    @two.update(status: :running)
    @three.update(status: :queued)
  end

  context 'default scope' do
    it 'orders by descending created_at' do
      expect(Workflow.first).to eq @one
    end

    it 'should override the uuid on creation' do
      expect(Workflow.first.uuid).to eq @uuid
    end

    it 'should not update the uuid' do
      val = @one.uuid
      @one.update_attributes :uuid => 'something-something'
      expect(@one.reload.uuid).to eq val
    end
  end

  context 'status scope' do
    it 'should get by status' do
      expect(Workflow.by_status('queued')).to match_array [@one, @three]
      expect(Workflow.by_status('running')).to match_array [@two]
    end
  end

  context 'uuid scope' do
    it 'should get by uuid' do
      expect(Workflow.by_uuid(@two.uuid)).to match_array [@two]
      expect(Workflow.by_uuid(@one.uuid)).to match_array [@one]
    end
  end

  context 'user_oauth_id scope' do
    it 'should get by user_oauth_id' do
      expect(Workflow.by_user_oauth_id(@two.user_oauth_id)).to match_array [@two]
      expect(Workflow.by_user_oauth_id(@one.user_oauth_id)).to match_array [@one]
    end
  end

  # context 'date_range scope' do
  #   before do
  #     # @range = [5.days.ago,1.days.ago]
  #     @range = "#{5.days.ago.strftime('%F')},#{1.days.ago.strftime('%F')}"
  #
  #   end
  #
  #   it 'should get by user_oauth_id' do
  #     expect(Workflow.by_date_range(@range)).to match_array [@one, @two]
  #     expect(Workflow.by_date_range(@range)).to_not match_array [@three]
  #   end
  # end

  describe 'after create' do
    it 'should start a workflow worker' do
      expect {
        @workflow = create(:workflow)
      }.to change(StartWorkflowWorker.jobs, :size).by(1)
    end
  end

  describe 'after update' do
    before do
      @workflow = create(:workflow)
    end

    context 'when status set to terminated' do
    end

    context 'when status set to running' do
    end
  end


  describe 'job status counts' do
    before do
      @workflow = create(:workflow)
      puts "JOBS SIZE #{@workflow.jobs.size}"
      5.times { create(:job, workflow: @workflow) }
      4.times { create(:job, workflow: @workflow, status: Job.statuses[:succeeded]) }
      @workflow.reload
      puts "JOBS SIZE #{@workflow.jobs.size}"
    end

    it 'should return counts' do
      expect(@workflow.jobs_running_count).to be 5
      expect(@workflow.jobs_succeeded_count).to be 4
      expect(@workflow.jobs_total_count).to be 9
    end

  end

  describe '#owner' do
    context 'user_oauth_id present' do
      before do
        @user = { 'name' => 'Tyler Martin',
                  'login' => 'tylernm14',
                  'oauth_id' => 123
                }
        @workflow = create(:workflow, user_oauth_id: '123')
        stub_request(:get, "#{ENV['USERS_URL']}/users/123").
            with(headers: {'Accept'=>'application/json', 'Authorization'=>'Token token=devtoken'}).
            to_return(status: 200, body: @user.to_json, headers: {})
      end

      it 'should return some user attributes' do
        expect(@workflow.owner.name).to eq (@user['name'])
      end
    end

    context 'user_oauth_id not present' do
      before do
        @workflow = create(:workflow)
      end

      it 'should return nil' do
        expect(@workflow.owner).to be nil
      end
    end

  end

  describe '#completed?' do
    it 'should be completed succeeded?' do
      expect(build(:workflow, status: :done).completed?).to be true
    end
    it 'should be completed failed?' do
      expect(build(:workflow, status: :failed).completed?).to be true
    end
    it 'should be completed terminated?' do
      expect(build(:workflow, status: :terminated).completed?).to be true
    end
    it 'should not be completed queued?' do
      expect(build(:workflow, status: :queued).completed?).to be false
    end
    it 'should not be completed running?' do
      expect(build(:workflow, status: :running).completed?).to be false
    end
  end

end
