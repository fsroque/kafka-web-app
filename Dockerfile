FROM ubuntu:16.04
MAINTAINER Francisco Roque <francisco.roque@sonat.no>

######################################### base part

# keep upstart quiet - 1
RUN dpkg-divert --local --rename --add /sbin/initctl
RUN ln -sf /bin/true /sbin/initctl

# no tty
ENV DEBIAN_FRONTEND noninteractive

# get up to date
RUN apt-get update --fix-missing

# global installs [applies to all envs!]
RUN apt-get install -y build-essential git
RUN apt-get install -y python3 python3-dev python3-setuptools
RUN apt-get install -y python3-pip

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
