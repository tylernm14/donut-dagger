require 'spec_helper'

describe JobDoneWorker, :type => :worker do

  before(:all) do
    enable_etcd_workflows
  end

  after(:all) do
    disable_etcd_workflows
  end

  it 'should have sidekiq queue' do
    expect(JobDoneWorker.sidekiq_options['queue']).to eq :job_done
  end

  it 'should have sidekiq retry' do
    expect(JobDoneWorker.sidekiq_options['retry']).to be true
  end

  it 'should have sidekiq backtrace' do
    expect(JobDoneWorker.sidekiq_options['backtrace']).to be true
  end

  describe '#perform' do
    before do
      allow(LaunchJobsWorker).to receive(:perform_async).with(any_args)
      @w = create(:workflow)
      @ew = EtcdWorkflow.new(@w.uuid)
      @root_job = Job.find_by_uuid(@w.root_job_uuid)
    end

    context 'job done' do
      before do
        # TODO: setup workflow and jobs by hand to match scenario
        @w.update!(parallelism: 2)
        @jobs = @w.jobs
        # D
        @jobs[3].update!(status: :succeeded) # Root job just succeeded
        # C
        @jobs[2].update!(status: :waiting)
        @jobs[2].update!(dependencies_succeeded_count: 0)
        # B
        @jobs[1].update!(status: :waiting)
        @jobs[1].update!(dependencies_succeeded_count: 0)
        # root job (A)
        @jobs[0].update!(status: :waiting)
        @ew.with_lock do |w|
          w.set_status(@w.status)
          4.times do |i|
            #puts "JOB UUID: #{@jobs[i].uuid}"
            j = EtcdWorkflow.job_repr(@jobs[i])
            w.set_job(j)
          end
        end
      end

      context 'workflow already completed' do
        it 'returns and messages error' do
          @w.done!
          #JobDoneWorker.new.perform(@jobs[1].id)
          expect{JobDoneWorker.new.perform(@jobs[1].id)}.to output(/ERROR: Job return after worklow completed/).to_stderr
        end

      end

      context 'job failed' do
        # it 'fails the workflow' do
        #   @jobs[1].failed!
        #   JobDoneWorker.new.perform(@jobs[1].id)
        #   @w.reload
        #   @ew.with_lock do |w|
        #     @status = w.get_status
        #   end
        #   expect(@status).to eq 'failed'
        #   expect(@w.failed?).to eq true
        # end
        it 'does not fail the entire workflow' do
          @jobs[1].failed!
          @w.running!
          @ew.with_lock { |w| @status = w.set_status 'running' }
          JobDoneWorker.new.perform(@jobs[1].id)
          @w.reload
          @ew.with_lock do |w|
            @status = w.get_status
          end
          expect(@status).to eq 'running'
          expect(@w.running?).to eq true
        end

      end

      #it "mark the root job as queued in etcd" do
        #@ew.with_lock do |w|
          #@queued_jobs = w.jobs_by_status(:queued)
        #end
        #expect(@queued_jobs.size).to eq 1
        #expect(@queued_jobs.values[0]['uuid']).to eq @root_job.uuid
      #end

      #it 'updates the workflow status to running' do
        #@w.reload
        #expect(@w.status).to eq "running"
      #end

      #it 'updates the etcd workflow status to running' do
        #@ew.with_lock { |w| @status = w.get_status }
        #expect(@status).to eq 'running'
      #end

      context 'job succeeded' do
        it 'updates the dependents' do
          expect(@jobs[1].waiting?).to be true
          expect(@jobs[2].waiting?).to be true
          @jobs[3].succeeded!
          JobDoneWorker.new.perform(@jobs[3].id)
          @w.reload
          @jobs.each { |j| j.reload }
          expect(@jobs[1].dependencies_succeeded_count).to eq 1
          expect(@jobs[2].dependencies_succeeded_count).to eq 1
          @ew.with_lock do |w|
            @ewjobs = w.jobs
          end
          expect(@ewjobs[@jobs[1].uuid]['dependencies_succeeded_count']).to eq 1
          expect(@ewjobs[@jobs[2].uuid]['dependencies_succeeded_count']).to eq 1
          expect(@jobs[1].queued?).to be true
          expect(@jobs[2].queued?).to be true
          expect(@ewjobs[@jobs[1].uuid]['status']).to eq 'queued'
          expect(@ewjobs[@jobs[2].uuid]['status']).to eq 'queued'
        end
        it 'calls launch jobs worker' do
          JobDoneWorker.new.perform(@jobs[3].id)
          expect(LaunchJobsWorker).to have_received(:perform_async).once
        end
      end

    end
  end
end
