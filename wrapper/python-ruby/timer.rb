#!/usr/bin/env ruby

require 'rest-client'
require 'json'
STDOUT.sync = true
def to_f_or_i_or_s(v)
  ((float = Float(v)) && (float % 1.0 == 0) ? float.to_i : float) rescue v
end

run_length_arg = ARGV[0]

unit = run_length_arg[-1]
secs = to_f_or_i_or_s(run_length_arg[0..-2])

if ARGV[1] != nil
  outdir = ARGV[1]
else
  outdir = '.'

end
if unit == 'm'
  secs = secs * 60
end
puts "Will contanct dagger at #{ENV['DAGGER_URL']}."
puts "Will run for #{secs} seconds."

curr = 0

start_time = curr_time = Time.now
last_print = start_time - 1.001
elapsed_time = 0
while elapsed_time <= secs do
  curr_time = Time.now
  if curr_time - last_print >= 1
    puts "Running for #{elapsed_time} seconds..."
    last_print = Time.now
  end
  curr_time = Time.now
  elapsed_time = curr_time - start_time
end
#while curr <= secs do
  #if curr != secs
    #puts "Running for #{curr} seconds..."
    #sleep 1
  #else
    #puts "Ran for #{curr} seconds."
  #end
  #curr = curr + 1
#end

output_str = "Ran for #{elapsed_time} seconds."
File.open(File.join(outdir, "output.txt"), 'w') { |file| file.write(output_str) }
puts output_str
puts "Timer Exit"

