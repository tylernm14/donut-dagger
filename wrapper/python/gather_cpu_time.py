#!/usr/local/bin/python -u
import os
from os.path import join
import sys
import argparse

parser = argparse.ArgumentParser(description='Process some job dir timing')
parser.add_argument('job_dirs', metavar='N', type=str, nargs='+', help='a folder name for timing accumulation')

args = parser.parse_args()
job_dirs = args.job_dirs
cpu_times = []
for dir in job_dirs:
  print 'Looking for {} output'.format(dir)
  filepath = join(dir, 'output.txt')
  if os.path.isfile(filepath):
    with open(filepath, 'r') as f:
      cpu_time = float(f.read().split(' ')[2])
      cpu_times.append(cpu_time)
      print '{} ran for {} seconds'.format(dir, cpu_time)
  else:
    sys.stderr.write("ERROR Couldn't find timing information for {}\n".format(dir))
s = 'Total cpu time = {}\n'.format(sum(cpu_times))
with open('total_cpu_time.txt', 'w') as f:
    f.write(s)


