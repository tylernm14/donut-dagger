require 'spec_helper'
require_relative '../../lib/etcd_utils'
require 'time'

describe EtcdWorkflow do

  before(:context) do
    Etcd::Log.init('./etcd_logfile')
    Etcd::Log.level(:debug)
    if not ENV['USE_EXISTING_ETCD']
      Etcd::Spawner.instance.start(3)
    end
    WebMock.disable!
  end

  before(:each) do
    # Cleanup dagger keys before each example
    EtcdUtils.pool.with do |conn|
      if conn.exists?('/dagger/')
        conn.delete('/dagger/', recursive: true)
      end
    end
    @w = EtcdWorkflow.new('wkfl_uuid')
  end

  after(:each) do
  end

  after(:context) do
    if not ENV['USE_EXISTING_ETCD']
      Etcd::Spawner.instance.stop
    end
    WebMock.enable!
  end

  context 'with lock' do
    let(:job) {
      {
        'uuid' => 'job_uuid',
        'fake' => 'data'
      }
    }

    it 'sets a workflow status' do
      @w.with_lock do |w|
        expect(w.set_status('succeeded')).to eq 'succeeded'
      end
    end

    it 'lets waiting consumer continue after release' do
      expect do
        @w.with_lock do |w|
          @t = Thread.new do
            @startTime = Time.now
            @w.with_lock do |w|
              @endTime = Time.now
            end
          end
          sleep 5
        end
        @t.join
      end.to output(/Failed test and set/).to_stdout
      expect(@endTime-@startTime).to be >= 5
    end

    context 'error within lock block' do
      it 'detects errors and releases lock' do
        expect_any_instance_of(EtcdLock).to receive(:release).once
        expect do
          @w.with_lock do |w|
            raise "Fake error"
          end
        end.to raise_error(RuntimeError, 'Fake error')
      end
    end

    context 'receives SIGTERM' do
      it 'it releases lock' do
        expect_any_instance_of(EtcdLock).to receive(:release).once
        expect do
          @w.with_lock do |w|
            raise SignalException.new('SIGTERM')
          end
        end.to raise_error(SignalException, 'SIGTERM')
      end

    end

    it 'waiting consumer raises error after watch timeout' do
      timeout_seconds = 5
      expect do
        @w.with_lock do |w|
          @t = Thread.new do
            @startTime = Time.now
            @w.with_lock(timeout_seconds) do |w|
              @endTime = Time.now
            end
          end
          sleep 8
        end
        @t.join
      end.to raise_error(Timeout::Error)
    end

    it 'retrieves jobs by status' do
      @w.with_lock do |w|
        w.set_job({ 'uuid' => '1', 'status' => 'succeeded'})
        w.set_job({ 'uuid' => '2', 'status' => 'succeeded'})
        w.set_job({ 'uuid' => '3', 'status' => 'failed'})
        w.set_job({ 'uuid' => '4', 'status' => 'succeeded'})
        w.set_job({ 'uuid' => '5', 'status' => 'failed'})
        expect(w.jobs_by_status('succeeded').size).to eq 3
        expect(w.jobs_by_status('failed').size).to eq 2
      end
    end

    context 'create a job' do
      it 'creates a job key from hash value' do
        @w.with_lock do |w|
          @result = w.set_job(job)
        end
        expect(@result).to eq job
      end
    end

    context 'update job status' do
      context 'of existing job' do
        it 'succeeds' do
          @w.with_lock do |w|
            set_result = w.set_job(job)
            @update_result = w.update_job_status(job['uuid'], 'succeeded')
          end
          expect(@update_result).to eq 'succeeded'
        end
      end
      context 'of non-existent job' do
        it 'raises exception' do
          @w.with_lock do |w|
            expect do
              @update_result = w.update_job_status(job['uuid'], 'succeeded')
            end.to raise_error(RuntimeError)
          end
        end
      end
    end

    it 'retrieves a job' do
      @w.with_lock do |w|
        set_result = w.set_job(job)
        @result = w.get_job(job['uuid'])
      end
      expect(@result['uuid']).to eq 'job_uuid'
    end


  end


end
