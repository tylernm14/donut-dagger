#!/usr/bin/env python -u

import pprint
import sys
from streamed_job import *
import json


pp = pprint.PrettyPrinter(indent=4)

workflow_uuid = sys.argv[1]
job_record = json.loads(sys.argv[2])
print job_record
job_desc = job_record['description']
job_desc['workflow_uuid'] = workflow_uuid
pp.pprint(job_desc)

cmd = job_desc['cmd']
args = job_desc['args']
cmd_list = [ cmd ].extend(args)

job = Job(job_record)
job.run()






