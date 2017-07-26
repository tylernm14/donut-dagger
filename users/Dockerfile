FROM ruby

# Non-interactive install of ubuntu packages
ENV DEBIAN_FRONTEND noninteractive
ENV RACK_ENV production


RUN apt-get update -y \
    # installing dev libs and packages
    && apt-get install -y \
      git \
      build-essential \
      libpq-dev \
      nginx \
      libpq5 \
      imagemagick \
    && gem install foreman bundler

RUN mkdir -p /app

COPY ./Gemfile /app
COPY ./Gemfile.lock /app

WORKDIR /app

RUN bundle install

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

ENV DEBIAN_FRONTEND newt
ENV TERM xterm
CMD foreman start -f Procfile-docker
