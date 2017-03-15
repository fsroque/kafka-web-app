FROM ubuntu:16.04
MAINTAINER Francisco Roque <francisco.roque@sonat.no>

# keep upstart quiet
RUN dpkg-divert --local --rename --add /sbin/initctl
RUN ln -sf /bin/true /sbin/initctl

# no tty
ENV DEBIAN_FRONTEND noninteractive

# get up to date
RUN apt-key update &&  \
    apt-get update && \
    apt-get install -y --allow-unauthenticated --no-install-recommends gnupg build-essential git python3 python3-dev python3-pip nginx supervisor python-setuptools && \
    apt-get remove -y --allow-unauthenticated python-pip curl gnupg && \
    rm -rf /var/lib/apt/lists/* 

WORKDIR /tmp
RUN git clone https://github.com/edenhill/librdkafka.git
WORKDIR /tmp/librdkafka
RUN ./configure && make && make install

RUN service supervisor stop

# create a virtual environment and install all depsendecies from pypi
#RUN pip3 install virtualenv
RUN pip3 install virtualenv && virtualenv -p /usr/bin/python3 /opt/venv && rm -Rf ~/.cache/pip
ADD requirements.txt /opt/venv/requirements.txt
RUN /opt/venv/bin/pip install -r /opt/venv/requirements.txt

# expose port(s)
EXPOSE 80

ENV PYTHONUNBUFFERED TRUE
ENV PYTHONHASHSEED 0

WORKDIR /opt/app
ADD app/ .


# install the modified supervisor_stdout
COPY supervisor_stdout /tmp/supervisor_stdout
RUN cd /tmp/supervisor_stdout && python setup.py install

# file management, everything after an ADD is uncached, so we do it as late as
# possible in the process.
ADD supervisord.conf /etc/supervisord.conf
ADD nginx.conf /etc/nginx/nginx.conf

# restart nginx to load the config
RUN service nginx stop

# Start supervisor
CMD supervisord -c /etc/supervisord.conf -n
