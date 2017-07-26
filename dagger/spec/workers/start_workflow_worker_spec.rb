require 'spec_helper'

describe StartWorkflowWorker, :type => :worker do

  before(:all) do
    enable_etcd_workflows
  end

  after(:all) do
    disable_etcd_workflows
  end

  it 'should have sidekiq queue' do
    expect(StartWorkflowWorker.sidekiq_options['queue']).to eq :start_workflow
  end

  it 'should have sidekiq retry' do
    expect(StartWorkflowWorker.sidekiq_options['retry']).to be true
  end

  it 'should have sidekiq backtrace' do
    expect(StartWorkflowWorker.sidekiq_options['backtrace']).to be true
  end

  describe '#perform' do
    context 'etcd workflow saves status' do
      before do
        allow(LaunchJobsWorker).to receive(:perform_async).with(any_args)
      end

      context 'workflow with one root' do
        before do
          @w = create(:workflow)
          @ew = EtcdWorkflow.new(@w.uuid)
          @root_job = @w.roots[0].job
          StartWorkflowWorker.new.perform(@w.id)
        end

        it 'makes entries for all jobs in etcd' do
          jobs = []
          @ew.with_lock do |w|
            jobs = w.jobs
          end
          expect(jobs.size).to eq 4
        end

        it "marks the root job as queued in etcd" do
          @ew.with_lock do |w|
            @queued_jobs = w.jobs_by_status(:queued)
          end
          expect(@queued_jobs.size).to eq 1
          expect(@queued_jobs.values[0]['uuid']).to eq @root_job.uuid
        end

        it 'updates the workflow status to running' do
          @w.reload
          expect(@w.status).to eq "running"
        end

        it 'updates the etcd workflow status to running' do
          @ew.with_lock { |w| @status = w.get_status }
          expect(@status).to eq 'running'
        end

        it 'calls launch jobs worker' do
          expect(LaunchJobsWorker).to have_received(:perform_async).once
        end

      end

      context 'workflow with multiple roots' do
        before do
          @w = create(:workflow_multi_root_definition)
          @ew = EtcdWorkflow.new(@w.uuid)
          @root_jobs_uuids = @w.roots.map { |r| r.job.uuid }
          StartWorkflowWorker.new.perform(@w.id)
        end
        it "marks multiple root jobs as queued in etcd" do
          @ew.with_lock do |w|
            @queued_jobs = w.jobs_by_status(:queued)
          end
          expect(@queued_jobs.size).to eq 2
          expect(all_roots_found?).to eq true
        end

        def all_roots_found?
          puts @queued_jobs.values.map {|v| v['uuid']}
          puts "ROOT JOBS: #{@root_jobs}"
          (@root_jobs_uuids & @queued_jobs.values.map {|v| v['uuid']}).any?
        end
      end
    end
  end
end
