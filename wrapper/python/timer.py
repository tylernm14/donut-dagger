#!/usr/local/bin/python -u

import json
import sys
import os
import time

#usage ./timer.py 2s | ./timer.py 2m | ./timer.py 2.5m
def to_f_or_i(v):
  print v
  try:
    f = float(v)
  except ValueError as e:
    f = int(v)
  return f

run_length_arg = sys.argv[1]
if len(sys.argv) == 3:
  outdir = sys.argv[2]
else:
  outdir = '.'

unit = run_length_arg[-1]
secs = to_f_or_i(run_length_arg[:-1])
if unit == 'm':
  secs = secs * 60
print "Will contanct dagger at {}.".format(os.environ.get('DAGGER_URL'))
print "Will run for {} seconds.".format(secs)

curr = 0

start_time = curr_time = time.time()
last_print = start_time - 1.001
elapsed_time = 0
while elapsed_time <= secs:
  curr_time = time.time()
  if curr_time - last_print >= 1:
    print "Running for {} seconds...".format(elapsed_time)
    last_print = time.time()
  curr_time = time.time()
  elapsed_time = curr_time - start_time
#while curr <= secs do
  #if curr != secs
    #puts "Running for #{curr} seconds..."
    #sleep 1
  #else
    #puts "Ran for #{curr} seconds."
  #end
  #curr = curr + 1
#end
output_str =  "Ran for {} seconds.\n".format(elapsed_time)
with open(os.path.join(outdir, 'output.txt'), 'w') as f:
  f.write(output_str)
print output_str


