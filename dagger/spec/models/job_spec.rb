require 'spec_helper'

describe Job, type: :model do
  before do
    #allow(JobDoneWorker).to receive(:perform_async).with(any_args)
    allow(CreateDagJobs).to receive(:call).with(any_args)
    #allow(StartWorkflowWorker).to receive(:perform_async).with(any_args)
  end

  it { should validate_presence_of(:status) }
  it { should validate_presence_of(:workflow) }
  it { should validate_presence_of(:name) }

  it { should define_enum_for(:status).with([:waiting, :launched, :queued, :running, :succeeded, :failed, :terminated, :dead]) }
  it { should belong_to(:workflow) }

  it { should have_and_belong_to_many(:dependencies).class_name('Job').join_table('job_edges') }
  it { should have_and_belong_to_many(:dependents).class_name('Job').join_table('job_edges') }

  context 'scopes' do

    before do
      Job.destroy_all
      @uuid = SecureRandom.uuid
      @one = create(:job, status: :queued)
      @two = create(:job, status: :running)
      @three = create(:job, status: :failed)
      @four = create(:job, status: :succeeded, uuid: @uuid)
    end

    context 'default scope' do
      it 'orders by descending created_at' do
        @two.touch
        expect(Job.first).to eq @four
      end

      it 'should override the uuid on creation' do
        expect(Job.first.uuid).to eq @uuid
      end

      it 'should not update the uuid' do
        val = @one.uuid
        @one.update_attributes :uuid => 'something-something'
        expect(@one.reload.uuid).to eq val
      end
    end

    context 'status scope' do
      it 'should get by state' do
        expect(Job.by_status('queued')).to match_array [@one]
        expect(Job.by_status('running')).to match_array [@two]
        expect(Job.by_status('failed')).to match_array [@three]
      end
    end

    context 'uuid scope' do
      it 'should get by state' do
        expect(Job.by_uuid(@two.uuid)).to match_array [@two]
        expect(Job.by_uuid(@one.uuid)).to match_array [@one]
      end
    end
  end

  context 'job graph' do
    before do
      JobEdge.destroy_all

      @uuid = SecureRandom.uuid
      @w = create(:workflow)
      @one = create(:job, workflow: @w, status: :queued)
      @two = create(:job, workflow: @w, status: :running)
      @three = create(:job, workflow: @w, status: :failed)
      @four = create(:job, workflow: @w, status: :succeeded, uuid: @uuid)
    end

    it 'creates job edges' do
      @two_to_three = create(:job_edge, dependency: @two, dependent: @three, workflow: @one.workflow)
      expect(@two.dependents.first).to eq(@three)
      expect(@three.dependencies.first).to eq(@two)
    end

    it 'should delete join entries if job is deleted' do
      @two_to_three = create(:job_edge, dependency: @two, dependent: @three, workflow: @one.workflow)
      @two_to_four = create(:job_edge, dependency: @two, dependent: @four, workflow: @one.workflow)
      expect { @two.destroy! }.to change { JobEdge.count }.by(-2)
    end
  end

  describe 'after update of status' do 
    context 'to completed state from running state' do
      before do
        @job = create(:job, status: :running)
      end
      it 'launches job-done-worker' do
        expect { 
          @job.update!(status: :succeeded)
        }. to change(JobDoneWorker.jobs, :size).by(1)
      end
    end
  end

  describe '#completed?' do
    it 'should be completed succeeded?' do
      expect(build(:job, status: :succeeded).completed?).to be true
    end
    it 'should be completed failed?' do
      expect(build(:job, status: :failed).completed?).to be true
    end
    it 'should be completed terminated?' do
      expect(build(:job, status: :terminated).completed?).to be true
    end
    it 'should not be completed queued?' do
      expect(build(:job, status: :queued).completed?).to be false
    end
    it 'should not be completed running?' do
      expect(build(:job, status: :running).completed?).to be false
    end
    it 'should not be completed waiting?' do
      expect(build(:job, status: :waiting).completed?).to be false
    end
    it 'should not be completed dead?' do
      expect(build(:job, status: :dead).completed?).to be true
    end
  end


end
