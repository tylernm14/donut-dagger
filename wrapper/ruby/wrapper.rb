#!/usr/bin/env ruby
#

require 'json'
require 'open3'
require 'pp'
require 'time'
require 'rest-client'

job_record = JSON.parse(ARGV[0])
job_desc = JSON.parse(ARGV[1])

auth = "Token token=#{ENV['ADMIN_TOKEN']}"
# ex.
# {
#   "name": "apple",
#   "cmd": "/timer.rb",
#   "args": [ "300s" ]
# }
STDOUT.sync = true
puts "Job Record:"
pp job_record
puts "Job Description"
pp job_desc
cmd = job_desc.fetch('cmd')
args = job_desc.fetch('args')

puts "Status change to 'running'..."
start_time = Time.now
response = RestClient.put "#{ENV['DAGGER_URL']}/jobs/#{job_record['id']}", { 'start_time' => start_time, 'status' => 'running' }.to_json, { content_type: :json, accept: :json, Authorization: auth}
puts "Response:\ncode: #{response.code}\nbody: #{response.body}"

puts "Running job \"#{job_desc.fetch('name')}\"."
exit_status = -1
full_cmd = "#{cmd} #{args.join(" ")}"
puts full_cmd
#Open3.popen3(full_cmd) do |stdin, stdout, stderr, wait_thr|
IO.popen(full_cmd + " 2>&1") do |c|
  c.each do |line|
    puts line
  end
end

end_time = Time.now
exitstatus = $?.exitstatus
puts "Process returned with exit status: #{exitstatus}"
if exitstatus == 0
  exit_state = 'succeeded'
else
  exit_state = 'failed'
end

puts "Status change to 'succeeded'.."
response = RestClient.put "#{ENV['DAGGER_URL']}/jobs/#{job_record['id']}", { 'end_time' => end_time, 'status' => exit_state }.to_json, { content_type: :json, accept: :json, Authorization: auth}
puts "Response:\ncode: #{response.code}\nbody: #{response.body}"
