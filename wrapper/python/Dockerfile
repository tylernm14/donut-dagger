FROM python:2
RUN wget https://bootstrap.pypa.io/get-pip.py
RUN python get-pip.py
RUN pip install requests backoff
COPY streamed_job/dist/streamed_job-0.1.0.tar.gz /
RUN pip install /streamed_job-0.1.0.tar.gz
COPY timer.py /
COPY gather_cpu_time.py /
CMD [ "/bin/bash", "-c", "run_streamed_job '{\"name\":\"apple\",\"cmd\":\"/timer.py\",\"args\":[\"5s\"]}'" ]
