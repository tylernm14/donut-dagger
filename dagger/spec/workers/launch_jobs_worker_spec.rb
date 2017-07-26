require 'spec_helper'
require 'json'
require 'yaml'
require 'pp'

describe LaunchJobsWorker, :type => :worker do

  before(:all) do
    enable_etcd_workflows
  end

  after(:all) do
    disable_etcd_workflows
  end

  it 'should have sidekiq queue' do
    expect(LaunchJobsWorker.sidekiq_options['queue']).to eq :launch_jobs
  end

  it 'should have sidekiq retry' do
    expect(LaunchJobsWorker.sidekiq_options['retry']).to be true
  end

  it 'should have sidekiq backtrace' do
    expect(LaunchJobsWorker.sidekiq_options['backtrace']).to be true
  end

  describe '#perform' do
    before do
      #@ew = double('etcd_wkfl')
      #allow(EtcdWorkflow).to receive(:new).and_yield(@ew)
      #allow(@ew).to receive(:with_lock).and_yield(@ew)

      EtcdUtils.pool.with do |conn|
        if conn.exists?('/dagger/')
          conn.delete('/dagger/', recursive: true)
        end
      end
      @kube_response = double('response')
      allow(@kube_response).to receive(:code).and_return 200
      allow(@kube_response).to receive(:body).and_return YAML.dump({'Awesome': 'Blossom'})
      allow(RestClient).to receive(:post).with(any_args).and_return @kube_response
      @w = create(:workflow)
      @ew = EtcdWorkflow.new(@w.uuid)
      ENV['KOPS_JOBS_INSTANCE_GROUP_KEY'] = 'red-nodes'
      max_job_nodes_data = {
          'spec' => {
              'maxSize' => 2
          }
      }
      s3 = double('s3')
      s3_object = double('s3_object')
      allow(s3_object).to receive(:body).and_return(max_job_nodes_data.to_yaml)
      # allow(Aws::S3::Client).to receive(:new).and_return(s3)
      # allow(s3).to receive(:get_object).and_return(s3_object)
      allow_any_instance_of(Aws::S3::Client).to receive(:get_object)
          .with(bucket: ENV['KOPS_STATE_STORE'], key: ENV['KOPS_JOBS_INSTANCE_GROUP_KEY']).and_return(s3_object)
    end

    def launch_and_reload
      LaunchJobsWorker.new.perform(@w.id)
      @w.reload
      @jobs.each {|j| j.reload}
    end

    context 'workflow completed' do
      before do
        @jobs = @w.jobs
        @ew.with_lock do |w|
          w.set_status(@w.status)
          4.times do |i|
            #puts "JOB UUID: #{@jobs[i].uuid}"
            j = EtcdWorkflow.job_repr(@jobs[i], status: :succeeded)
            w.set_job(j)
          end
        end
      end

      it 'marks workflow as done' do
        launch_and_reload
        puts "About to aquire delete ew "
        expect {
          @ew.with_lock do |w|
          end
        }.to raise_error EtcdLock::LockKeyNotFound
        expect(@w.done?).to be true
      end
    end

    context 'jobs remain to be processed' do
      context 'there are jobs with fulfilled dependencies' do
        context 'there is unused processing parallelism' do
          before do
            # TODO: setup workflow and jobs by hand to match scenario
            @w.update!(parallelism: 2)
            @jobs = @w.jobs
            # D
            @jobs[3].update!(status: :succeeded)
            # C
            @jobs[2].update!(status: :queued)
            @jobs[2].update!(dependencies_succeeded_count: 1)
            # B
            @jobs[1].update!(status: :running)
            @jobs[1].update!(dependencies_succeeded_count: 1)
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
            @w.update!(launched_jobs_count: 1)

            nodes_resp_data =  [
                {
                    'metadata' => { 'labels' => { 'cpu_usage' => 'red'}},
                    'status' => { 'allocatable' => { 'cpu' => '2',
                                                     'memory' => '8175252Ki' },
                                  'capacity' => { 'cpu' => '4',
                                                  'memory' => '8000000Ki' }
                                }
                },
                {
                    'metadata' => { 'labels' => { 'cpu_usage' => 'red'}},
                    'status' => { 'allocatable' => { 'cpu' => '2',
                                                     'memory' => '8175252Ki' },
                                  'capacity' => { 'cpu' => '4',
                                                  'memory' => '8000000Ki' }
                    }
                }
            ]
            job_scheduled_data =
                {
                    'status' => { 'conditions' => [ { 'type' => 'PodScheduled',
                                                      'status' => 'True'
                                                    } ] }
                }
            job_unscheduled_data =
                {
                    'status' => { 'conditions' => [ { 'type' => 'PodScheduled',
                                                      'status' => 'False',
                                                      'reason' => 'Unschedulable'
                                                    } ] }
                }
            jobname = "#{@jobs[2].workflow.uuid}-#{@jobs[2].name}"
            podname = "#{jobname}-#{SecureRandom.hex(2)}"
            pod_of_job_data =
                {
                    'items' => [ { 'metadata' => { 'name' => podname } } ]
                }
            launched_job_data =
            {
                    'metadata' => { 'name' =>  jobname }
                }
            allow(RestClient).to receive(:post).with("#{LaunchJobsWorker::KUBE_API_ADDR}/apis/batch/v1/namespaces/default/jobs")
            pod_of_job_resp = double('pod_of_job')
            allow(pod_of_job_resp).to receive(:body).and_return(pod_of_job_data.to_json)
            allow(RestClient).to receive(:get).with("#{LaunchJobsWorker::KUBE_API_ADDR}/api/v1/namespaces/default/pods/?labelSelector=job-name%3D#{jobname}")
              .and_return(pod_of_job_resp)
            job_scheduled_resp = double('job_scheduled')
            allow(job_scheduled_resp).to receive(:body).and_return(job_scheduled_data.to_json)
            allow(RestClient).to receive(:get).with("#{LaunchJobsWorker::KUBE_API_ADDR}/api/v1/namespaces/default/pods/#{podname}")
              .and_return(job_scheduled_resp)
          end

          it 'increments launched jobs count' do
            expect(@w.jobs_launched_count + @w.jobs_running_count).to eq 1
            launch_and_reload
            expect(@w.jobs_launched_count + @w.jobs_running_count).to eq 2
          end
          it 'sets status of jobs as running in etcd' do
            @ew.with_lock do |w|
              expect(w.jobs_by_status('running').size).to eq 1
            end
            launch_and_reload
            @ew.with_lock do |w|
              jobs = w.jobs_by_status('running')
              expect(jobs.size).to eq 2
            end
          end
          it 'launches jobs with fulfilled dependencies' do
            launch_and_reload
            expect(RestClient).to have_received(:post).with('http://localhost:8001/apis/batch/v1/namespaces/default/jobs', any_args).once
          end
          it 'marks the job as launched' do
            launch_and_reload
            #expect('launched').to eq(@jobs[2].status).or(eq(@jobs[]))
            expect(@jobs[2].status).to eq 'launched'
          end
        end
        #context 'there is no room for more parallelism' do
          #it 'requeues the job' do
          #end
        #end
      end
      #context 'thre are no jobs with fulfilled dependencies' do
        #it 'requeues the job' do
        #end
      #end
    end
    #context 'all jobs are done' do
      #it 'marks the workflow as done' do
      #end
    #end
  end

end
