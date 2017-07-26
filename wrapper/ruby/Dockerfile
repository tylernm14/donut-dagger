FROM ruby
RUN gem install rest-client
ADD timer.rb /
ADD wrapper.rb /
CMD [ "/bin/bash", "-c", "/wrapper.rb '{\"name\":\"apple\",\"cmd\":\"/timer.rb\",\"args\":[\"30s\"]}'" ]
