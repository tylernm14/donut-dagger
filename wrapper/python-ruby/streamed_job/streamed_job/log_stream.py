import sys
from threading import Thread
from time import sleep
import time

class LogStream(object):
    def __init__(self, sys_stream, persist_method, name, persist_interval = 10):
        self.sys_stream = sys_stream
        self.buffer = []
        self.buffer_persisted = True
        self.closed = False
        self.persist_method = persist_method
        self.name = name
        self.persist_interval = persist_interval
        self.persist_t = Thread(target=self.persist_thread)
        self.persist_t.start()
        self.output_prefix = self.name.upper() + ': '

    def write(self, str, call_persist = True):
        #  print "WRITING str to {}".format(self.name)
        if str != '':
            self.sys_stream.write(self.output_prefix + str)
            self.sys_stream.flush()
            self.buffer.append(str)
            if call_persist:
                self.buffer_persisted = False

    def persist_thread(self):
        start_time = time.time()
        while not self.closed:
            elapsed_time = time.time() - start_time
            #  sys.stderr.write("Elasted time {}\n".format(elapsed_time))
            #  sys.stderr.write("Persit interval {}\n".format(self.persist_interval))
            #  sys.stderr.write("Buffer persisted {}\n".format(self.buffer_persisted))
            if elapsed_time >= self.persist_interval and not self.buffer_persisted:
                #  sys.stderr.write("Time to persist!\n")
                self.persist()
                start_time = time.time()
            sleep(0.02)

    def persist(self):
        #  sys.stderr.write("In persist\n")
        if self.persist_method:
            #  sys.stderr.write("About to call persist method\n")
            self.persist_method(self.buffer)

    def close(self):
        self.closed = True
        self.persist_t.join
        self.persist()

    def is_closed(self):
        return self.closed


