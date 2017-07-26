#!/usr/bin/env python
import pprint
import subprocess
import sys
import select
import signal
from threading import Thread
from time import sleep
import json
from os.path import join, basename, splitext, dirname
import uuid
import os
import requests
import errno
import re
import backoff
import time
from time import gmtime, strftime
from shutil import make_archive, copyfile, move
from backports import tempfile
import zipfile
import traceback

from log_stream import *
from streamed_process import *
from external_resource import *


pp = pprint.PrettyPrinter(indent=4)

def mkdir_p(path):
    try:
        os.makedirs(path)
    except OSError as exc:  # Python >2.5
        if exc.errno == errno.EEXIST and os.path.isdir(path):
            pass
        else:
            raise


class LocalPathNotFoundException(Exception): pass
class Job(object):
    MAX_TIMEOUT = os.environ.get('MAX_TIMEOUT') or 7200
    def __init__(self, record):
        self.record = record
        self.shared_vol = os.environ.get('SHARED_FS_MOUNT_PATH') or '/srv'
        self.data = self.record['description']
        self.workdir = join(self.shared_vol, 'workflows', self.data['workflow_uuid'], self.data.get('workdir_prefix') or '')
        mkdir_p(self.workdir)
        os.chdir(self.workdir)
        self.workflow_resource = WorkflowResource()
        self.workflow_data = self.workflow_resource.get('?by_uuid={}'.format(self.data['workflow_uuid']))
        print self.workflow_data
        self.workflow_id = self.workflow_data[0]['id']
        self.workflow_uuid = self.workflow_data[0]['uuid']
        self.job_resource = JobResource()
        self.job_id = self.record['id']
        self.job_uuid =  self.record['uuid']
        self.local_input_resource = LocalInputResource()
        self.persist_interval = 10
        self.stdout = LogStream(sys.stdout, lambda buffer: self.job_resource.update(self.job_id, { 'stdout': ''.join(buffer) }), 'stdout', self.persist_interval)
        self.stderr = LogStream(sys.stderr, lambda buffer: self.job_resource.update(self.job_id, { 'stderr': ''.join(buffer) }), 'stderr', self.persist_interval)
        self.stdout.write("WORKDIR: {}\n".format(self.workdir))
        self.sp = None
        self.exit_status = None

    def persist_stdout(self):
        def persister(self, buffer):
            #  sys.stderr.write("BUFFER: {}".format(buffer))
            self.job_resource.update(self.job_id, { 'stdout': buffer })
        return persister

    def run(self):
        try:
            self.job_resource.update(self.job_id, { 'status': 'running', 'start_time': self.gmt_time() })
            self.stdout.write("Running job on HOSTNAME: {}\n".format(os.environ.get('HOSTNAME')))
            self.stdout.write("JOB DATA:\n{}\n".format(pp.pformat(self.data)))
            self.download_cached_files()
            self.gather_inputs()
            cmd = self.data['cmd']
            args = self.data['args']
            cmd_list = [cmd]
            cmd_list.extend(args)
            timeout = self.data.get('timeout') or self.MAX_TIMEOUT
            self.stdout.write("Running requested process... '{}'\n".format(' '.join(cmd_list)))
            self.sp = StreamedProcess(cmd_list, timeout, self.stdout, self.stderr, self.termination_check)
            self.exit_status = self.sp.run()
            self.job_resource.update(self.job_id, { 'status': self.exit_status, 'end_time': self.gmt_time() })
            self.gather_outputs()
        except Exception as e:
            if self.sp:
                self.sp.terminate()
            if self.exit_status:
                self.stderr.write("Process returned with '{}', but main job thread failed.\n".format(self.exit_status))
            self.job_resource.update(self.job_id, { 'status': 'failed', 'end_time': self.gmt_time() })
            self.stderr.write(traceback.format_exc())
            raise e
        finally:
            self.cleanup_persist_threads()

    def termination_check(self):
        workflows = self.workflow_resource.get('?by_uuid={}'.format(self.workflow_uuid))
        jobs = self.job_resource.get('?by_uuid={}'.format(self.job_uuid))
        if len(workflows) == 0 or len(jobs) == 0:
            return True
        else:
            workflow = workflows[0]
            job = jobs[0]
        return job['status'] == 'terminated' or workflow['status'] == 'terminated'

    def gmt_time(self):
        return strftime("%Y-%m-%d %H:%M:%S", gmtime()) + ' UTC'

    def download_cached_files(self):
        caches = self.local_input_resource.get("?by_workflow_uuid={}".format(self.workflow_uuid))
        if len(caches) > 0:
            mkdir_p('cached_files')
            headers = { 'Authorization': 'Token token={}'.format(os.environ['ADMIN_TOKEN']) }
            for c in caches:
                print "Found cache: {}".format(c)
                id = c['id']
                filename = c['name']
                url = '{}/local_inputs/{}/download'.format(os.environ['CELLAR_URL'], id)
                self.get_url(url, join('cached_files', filename), headers=headers)

    def gather_inputs(self):
        if 'inputs' in self.data:
            for i in self.data['inputs']:
                self.stdout.write("Gathering input:\n{}\n".format(pp.pformat(i)))
                mkdir_p(join(self.workdir, os.path.dirname(i['local'])))
                if 'content' in i:
                    self.write_contents(i)
                elif 'origin' in i:
                    self.get_input_url(i)
                elif 'cache' in i:
                    self.move_cache_file(i)
                elif 'move' in i:
                    self.move(i)
                elif 'local' in i:
                    self.check_path_exists(i['local'])
                else:
                    self.stdout.write('Found unknown input entry: {}\n'.format(i))

    def write_contents(self, i):
        filepath = join(self.workdir, i['local'])
        with open(filepath, 'w') as f:
            f.write(i['content'])

    def check_path_exists(self, path):
        if not os.path.isfile(path) and not os.path.isdir(path):
            raise LocalPathNotFoundException('Could not find file at {}'.format(os.path.abspath(path)))

    def move_cache_file(self, i):
        cached_file = join('cached_files', i['cache'])
        self.check_path_exists(cached_file)
        dest_path = i['local']
        move(cached_file, dest_path)

    def move(self, i):
        self.check_path_exists(i['move'])
        move(i['move'], i['local'])

    def get_input_url(self, i):
        headers = {}
        if 'auth' in i:
            headers['Authorization'] = self.get_auth_header(i['auth'])
        if 'post' in i and i['post'].lower() == 'json-zipfile':
            self.get_json_zipfile_url(i['origin'], join(self.workdir, i['local']), headers)
        else:
            self.get_url(i['origin'], join(self.workdir, i['local']), headers)

    def get_auth_header(self, auth_string):
        matches =  re.search(r'{{(.+?)}}', auth_string)
        if matches:
            sub = os.environ[matches.group(1)]
            return re.sub(r'{{.+?}}', sub, auth_string)
        else:
            return auth_string

################# THIS SHOULD BE A PLUGIN TYPE THING TO EXTEND THE INPUT DSL #####################
    def get_json_zipfile_url(self, url, dest_filepath, headers={}):
        response = requests.get(url, headers=headers)
        data = response.json()
        zip_url = data[0]['zip_file']['url']
        self.get_url(zip_url, dest_filepath)
##################################################################################################

    def get_url(self, url, dest_filepath, **kwargs):
        response = requests.get(url, **kwargs)
        with open(dest_filepath, 'wb') as f:
            f.write(response.content)

    def gather_outputs(self):
        if 'outputs' in self.data:
            for o in self.data['outputs']:
                self.stdout.write("Gathering output:\n{}\n".format(pp.pformat(o)))
                mkdir_p(join(self.workdir, dirname(o['local'])))
                if 'local' in o:
                    path = o['local']
                    try:
                        self.check_path_exists(o['local'])
                        if self.to_be_zipped(o):
                            self.save_zipped_result(path)
                        elif self.to_be_saved(o):
                            self.save_result(path)
                    except LocalPathNotFoundException as e:
                        self.stderr.write("Local output path '{}' does not exist.\n".format(path))
                else:
                    self.stdout.write('Found unknown output entry: {}\n'.format(o))

    def to_be_saved(self, o):
        return self.is_truthy(o, 'save')

    def to_be_zipped(self, o):
        return self.is_truthy(o, 'zip')

    def is_truthy(self, o, key):
        if key in o:
            val = o[key]
            if val == True or val.lower() == 'true':
                return True
        return False

    def save_zipped_result(self, path):
        with tempfile.TemporaryDirectory() as tmpdir:
            archive_name = basename(path)
            if os.path.isfile(path):
                archive_filepath = join(tmpdir, archive_name + '.zip')
                zipfile.ZipFile(archive_filepath, mode='w').write(path, basename(path))
            elif os.path.isdir(path):
                archive_path = join(tmpdir, archive_name)
                make_archive(archive_path, 'zip', root_dir=path)
                archive_filepath = archive_path + '.zip'
            else:
               raise RuntimeError('path {} doesnt exist'.format(path))
            self.save_result(archive_filepath, filename=basename(archive_filepath), content_type='application/zip')


    def save_result(self, path, filename=None, content_type=None):
        image_ext = [ 'png', 'jpeg', 'tif', 'gif' ]
        result = ResultResource()
        if not filename:
            filename = basename(path)
        if not content_type:
            # get extension without leading '.'
            ext = splitext(path)[1][1:]
            if ext == 'jpg':
                ext = 'jpeg'
            if ext.lower() in image_ext:
                content_type = 'image/' + ext
            elif ext.lower() == 'zip':
                content_type = 'application/zip'
            else:
                content_type = 'application/octet-stream'
        form_data = { 'name': filename, 'workflow_id': self.workflow_id, 'job_id': self.job_id, 'job_name': self.record['name'] }
        self.stdout.write("Form data: {}\n".format(form_data))
        self.stdout.write("Filepath: {}\n".format(path))
        self.stdout.write("Content-Type: {}\n".format(content_type))
        files = { 'file': (filename, open(path, 'rb'), content_type, {'Expires': '0'}) }
        result.post_form(form_data, files)

    def cleanup_persist_threads(self):
        if not self.stdout.is_closed(): self.stdout.close()
        if not self.stderr.is_closed(): self.stderr.close()

