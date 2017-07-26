FROM ruby

# Non-interactive install of ubuntu packages
ENV DEBIAN_FRONTEND noninteractive
ENV RACK_ENV production

ENV TERM xterm

RUN apt-get update -y \
    # installing dev libs and packages
    && apt-get install -y \
      git \
      build-essential \
      libpq-dev \
      nginx \
    && gem install foreman bundler

RUN mkdir -p /app

COPY ./Gemfile /app
COPY ./Gemfile.lock /app

WORKDIR /app

RUN bundle install
#
# use "MY" prefix to avoid collsion with actual ETCD env vars
ENV MY_ETCD_VERSION_NUM v2.3.7
ENV MY_ETCD_VERSION etcd-${MY_ETCD_VERSION_NUM}-linux-amd64
RUN curl -L  https://github.com/coreos/etcd/releases/download/${MY_ETCD_VERSION_NUM}/${MY_ETCD_VERSION}.tar.gz -o /${MY_ETCD_VERSION}.tar.gz && mkdir /etcd && tar xzvf /${MY_ETCD_VERSION}.tar.gz -C /etcd && rm /${MY_ETCD_VERSION}.tar.gz && cp /etcd/${MY_ETCD_VERSION}/etcd /usr/local/bin/etcd
ENV ETCD_BIN /usr/local/bin/etcd

COPY . /app

    # configuring nginx
RUN cp config/nginx.conf /etc/nginx/nginx.conf \
    && cp config/nginx-sites.conf /etc/nginx/sites-enabled/default \
    && sed -i -- 's/REPLACE_WITH_PORT/80/g' /etc/nginx/sites-enabled/default \
    && chown -R www-data:www-data /var/lib/nginx



    # removing dev packages
RUN apt-get remove -y \
      git \
      build-essential \
      libpq-dev \

    # reinstalling release packages
    && apt-get install -y \
        libpq5 \

    # cleanup
    && apt-get autoclean -y \
    && apt-get clean -y \

    # removing apt caches and temps
    && rm -rf /var/lib/apt/lists/* \
           /tmp/* \
           /var/tmp/*

CMD foreman start -f Procfile-docker
