import subprocess
import select
import sys
import signal
from threading import Thread
from time import sleep
import time
from log_stream import *
import atexit
import os

class TimeoutError(Exception): pass
class timeout:
    def __init__(self, seconds=1, error_message='Timeout'):
        self.seconds = seconds
        self.error_message = error_message
    def handle_timeout(self, signum, frame):
        raise TimeoutError(self.error_message)
    def __enter__(self):
        signal.signal(signal.SIGALRM, self.handle_timeout)
        signal.alarm(self.seconds)
    def __exit__(self, type, value, traceback):
        signal.alarm(0)


class StreamedProcess(object):

    def __init__(self, cmd_list, timeout, stdout_log_stream, stderr_log_stream, is_terminated_func):
        self.cmd_list = cmd_list
        self.timeout = timeout
        self.proc = None
        self.stdout = stdout_log_stream
        self.stderr = stderr_log_stream
        self.select_t = None
        self.succeeded = False
        self.timed_out = False
        self.terminated = False
        self.workflow_terminated = False
        self.is_terminated_func = is_terminated_func
        self.error = None

    def run(self):
        self.start_streaming_process_thread()
        self.timed_wait_with_term_check()
        proc_exitstatus = self.record_proc_summary()
        return proc_exitstatus


    def is_running(self):
        return self.proc.poll() is None and self.error is None

    def is_termination_triggered(self):
        return self.is_terminated_func()

    def start_streaming_process_thread(self):
        self.proc = subprocess.Popen(self.cmd_list, stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=0, preexec_fn=os.setsid)
        sleep(0)
        atexit.register(self.terminate)
        self.select_t = Thread(target=self.collect_proc_output)
        self.select_t.daemon = True
        self.select_t.start()

    def collect_proc_output(self):
        try:
            while self.is_running():
                reads = [self.proc.stdout.fileno(), self.proc.stderr.fileno()]
                ret = select.select(reads, [], [])
                for fd in ret[0]:
                    if fd == self.proc.stdout.fileno():
                        read = self.proc.stdout.readline()
                        self.stdout.write(read)
                    if fd == self.proc.stderr.fileno():
                        read = self.proc.stderr.readline()
                        self.stderr.write(read)
                sleep(0)
            if self.proc.poll() is not None:
                for line in self.proc.stdout.readlines():
                    self.stdout.write(line)
                for line in self.proc.stderr.readlines():
                    self.stderr.write(line)
                self.stdout.write("Process returned code: {}\n".format(self.proc.returncode))
                if self.proc.returncode == 0: self.succeeded = True
        except Exception as e:
            self.error = True
            self.terminate()
            raise e

    def timed_wait_with_term_check(self):
        try:
            with timeout(self.timeout):
                self.termination_check()
        except TimeoutError as err:
            self.stdout.write("Timeout triggered\n".format(self.timeout))
            self.timed_out = True
            self.terminate()
        self.select_t.join()

    def termination_check(self):
        while self.is_running():
            if self.is_termination_triggered():
                self.stdout.write("Termination triggered\n")
                self.terminate()
            sleep(0)

    def terminate(self):
        if self.proc and self.proc.poll() is None and not self.terminated:
            self.stdout.write("Sending SIGTERM...\n")
            os.killpg(os.getpgid(self.proc.pid), signal.SIGTERM)
            self.terminated = True

    def record_proc_summary(self):
        proc_status = None
        if not self.timed_out:
            if self.terminated:
                self.stdout.write('Process terminated\n')
                proc_status = 'terminated'
            elif not self.succeeded:
                self.stdout.write('Process failed!\n')
                proc_status = 'failed'
            else:
                self.stdout.write('Process succeeded :-)\n')
                proc_status = 'succeeded'
        else:
            msg = 'Timeout error after {} seconds\n'.format(self.timeout)
            self.stderr.write(msg)
            self.stdout.write(msg)
            proc_status = 'dead'
        return proc_status

