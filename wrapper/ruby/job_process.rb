#!/usr/bin/env ruby
#

require 'json'
require 'open3'
require 'pp'
require 'time'
require 'rest-client'
require 'logger'
#
# ex.
# {
#   "name": "apple",
#   "cmd": "/timer.rb",
#   "args": [ "300s" ]
# }
class JobProcess

  def initialize(job_record, job_desc, log_level=Logger::DEBUG)
    @logger = Logger.new(STDOUT)
    @logger.level = log_level
    @job_record = job_record  # dict representing job as in database
    @job_desc = job_desc
    @auth = "Token token=#{ENV['ADMIN_TOKEN']}"
    STDOUT.sync = true
    puts "Job Record:"
    pp job_record
    puts "Job Description"
    pp job_desc
  end

  def run
    puts "Status change to 'running'..."
    start_time = Time.now
    update_job(start_time: start_time, status: :running)
    exitstatus = call_cmd
    puts "Status change to 'succeeded'.."
    end_time = Time.now
    update_job(end_time: end_time, status: exitstatus_to_str(exitstatus)
  end

  def update_job(attributes)
    response = RestClient.put "#{ENV['DAGGER_URL']}/jobs/#{@job_record['id']}",
      attributes.to_json, { content_type: :json, accept: :json, Authorization: @auth}
    puts "Response:\ncode: #{response.code}\nbody: #{response.body}"
  end

  def gather_inputs

  end

  def call_cmd
    cmd = @job_desc.fetch('cmd')
    args = @job_desc.fetch('args')

    puts "Running job \"#{@job_desc.fetch('name')}\"."
    exit_status = -1
    full_cmd = "#{cmd} #{args.join(" ")}"
    puts full_cmd
    #Open3.popen3(full_cmd) do |stdin, stdout, stderr, wait_thr|
    IO.popen(full_cmd + " 2>&1") do |c|
      c.each do |line|
        puts line
      end
    end
    puts "Process returned with exit status: #{$?.exitstatus}"
    $?.exitstatus
  end

  def exitstatus_to_str(exitstatus)
    if exitstatus == 0
      'succeeded'
    else
      'failed'
    end
  end
end

if __FILE__ = $0
  job_record = JSON.parse(ARGV[0])
  job_desc = JSON.parse(ARGV[1])
  Jobrocess.new.run(job_record, job_desc)
end
