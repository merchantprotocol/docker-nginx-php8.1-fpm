FROM ubuntu:22.04
#FROM ubuntu:21.10

LABEL maintainer="Jonathon Byrdziak"

ARG NODE_VERSION=16
ARG USER_ID=1000
ARG GROUP_ID=1000 

WORKDIR /var/www/html
USER root

ENV DEBIAN_FRONTEND noninteractive
ENV TZ=UTC

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

## Set proper user/group permissions before running scripts 
# www-data:www-data maps to user 33:33, we want it to map to 1000:1000, 
# the primary user on the host machine
RUN userdel -f www-data \
    && if getent group www-data ; then groupdel www-data; fi

# The dialout group conflicts with MAC and removing it isn't a problem...
RUN if getent group dialout ; then groupdel dialout; fi

RUN addgroup --gid ${GROUP_ID} www-data &&\
    useradd -l -u ${USER_ID} -g www-data www-data &&\
    install -d -m 0755 -o www-data -g www-data /home/www-data &&\
    chown --changes --silent --no-dereference --recursive \
          --from=33:33 ${USER_ID}:${GROUP_ID} \
        /home/www-data

RUN apt-get update \
    && apt-get install lsb-release ca-certificates apt-transport-https software-properties-common -y \
    && add-apt-repository ppa:ondrej/php \
    && apt-get install -y gnupg gosu curl zip unzip git supervisor sqlite3 libcap2-bin libpng-dev python2


RUN apt-get update \
    && apt-get install -y php8.1-cli php8.1-dev \
       php8.1-pgsql php8.1-sqlite3 php8.1-odbc php8.1-gd \
       php8.1-curl php8.1-memcached \
       php8.1-imap php8.1-mysql php8.1-mbstring \
       php8.1-xml php8.1-zip php8.1-bcmath php8.1-soap \
       php8.1-intl php8.1-readline php8.1-pcov \
       php8.1-msgpack php8.1-igbinary php8.1-ldap \
       php8.1-redis php8.1-xdebug \
       php8.1-fpm \
    && php -r "readfile('http://getcomposer.org/installer');" | php -- --install-dir=/usr/bin/ --filename=composer \
    && curl -sL https://deb.nodesource.com/setup_$NODE_VERSION.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g npm \
    && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list \
    && apt-get update \
    && apt-get install -y yarn \
    && apt-get install -y mysql-client \
    && apt-get install -y postgresql-client \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && apt-get update -y \
    && apt-get install nginx -y

# Install Databricks Driver
RUN apt-get update \
    && apt-get install -y unixodbc unixodbc-dev libsasl2-modules-gssapi-mit wget
RUN wget https://databricks-bi-artifacts.s3.us-east-2.amazonaws.com/simbaspark-drivers/odbc/2.6.29/SimbaSparkODBC-2.6.29.1049-Debian-64bit.zip
RUN unzip SimbaSparkODBC-2.6.29.1049-Debian-64bit.zip
RUN dpkg -i simbaspark_2.6.29.1049-2_amd64.deb

# Fix ODBC MaxStringLength 255
RUN wget https://github.com/php/php-src/archive/refs/tags/php-$(php -r 'echo PHP_VERSION;').zip
RUN unzip php-$(php -r 'echo PHP_VERSION;').zip
RUN sed -i 's/if (colsize < 256 && !S->going_long) {/if (1) {/g' php-src-php-$(php -r 'echo PHP_VERSION;')/ext/pdo_odbc/odbc_stmt.c
RUN cd php-src-php-$(php -r 'echo PHP_VERSION;')/ext/pdo_odbc \
    && phpize \
    && ./configure --with-pdo-odbc=unixODBC,/usr/ \
    && make install

# A couple tools for us
RUN apt-get update \
   && apt-get install pip -y \
   && pip install ngxtop nano

#RUN apt-get update && \
#      apt-get -y install sudo

#RUN curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash \
#    && NR_INSTALL_SILENT=1 /usr/local/bin/newrelic install -n nginx-open-source-integration

RUN setcap "cap_net_bind_service=+ep" /usr/bin/php8.1
RUN mkdir /opt/scripts/

COPY start-container /usr/local/bin/start-container
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

COPY nginx/make-localhost-cert /opt/scripts/make-localhost-cert
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/sites-enabled/default.conf /etc/nginx/sites-available/default
COPY nginx/sites-enabled/default-ssl.conf /etc/nginx/sites-enabled/default-ssl

COPY php/php-fpm.conf /etc/php/8.1/fpm/pool.d/www.conf
COPY php/php.ini /etc/php/8.1/cli/php.ini
COPY php/php.ini /etc/php/8.1/fpm/php.ini
COPY php/opcache.ini /etc/php/8.1/mods-available/opcache.ini
RUN mkdir -p /var/run/php

RUN rm -f /var/www/html/index.nginx-debian.html
RUN mkdir /var/www/html/nginx.d/ 
COPY html/* /var/www/html/

# Installing the cron
RUN apt-get update -y && apt-get install cron -yqq

RUN rm -Rf /etc/cron.daily
RUN rm -Rf /etc/cron.weekly
RUN rm -Rf /etc/cron.monthly
RUN rm -Rf /etc/cron.hourly

COPY cron/samplecron.sh /var/www/html/cron.d/samplecron.sh
COPY cron/runcron.sh /opt/scripts/runcron.sh
COPY cron/crontab /etc/cron.d/webapp

RUN crontab /etc/cron.d/webapp
RUN touch /var/log/cron.log
RUN mkdir /var/log/cron/
RUN chmod 0600 /etc/cron.d/webapp

#######  Turn on/Run the container #########
RUN service php8.1-fpm start
RUN chmod +x /usr/local/bin/start-container

EXPOSE 80
EXPOSE 443

## Finally start the container services...
ENTRYPOINT ["start-container"]