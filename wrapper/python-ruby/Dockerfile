FROM python:2
RUN apt-get update && apt-get install -y ruby  ruby-dev
RUN gem install rest-client
RUN wget https://bootstrap.pypa.io/get-pip.py
RUN python get-pip.py
RUN pip install requests backoff
COPY streamed_job/dist/streamed_job-0.1.0.tar.gz /
RUN pip install /streamed_job-0.1.0.tar.gz
COPY timer.py /
COPY timer.rb /
COPY gather_cpu_time.py /
CMD [ "/bin/bash", "-c", "run_streamed_job '{\"name\":\"apple\",\"cmd\":\"/timer.py\",\"args\":[\"5s\"]}'" ]
