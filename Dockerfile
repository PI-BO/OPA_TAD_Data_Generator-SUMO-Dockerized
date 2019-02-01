# To build the container:
#   sudo docker build -t "localhost:sumo1.1.0" .
#
# To run the container interactively:
#   sudo docker run -i -t "localhost:sumo1.1.0" /bin/bash

##################################################################
# Build Container definition
##################################################################
FROM ubuntu:18.10 as sumo_builder

MAINTAINER Christian Duentgen (duentgen@gmx.de)
LABEL Description="Dockerised Simulation of Urban MObility (SUMO)"

ENV SUMO_VERSION 1.1.0
ENV SUMO_HOME /opt/sumo
ENV SUMO_USER sumouser
ENV SUMO_HOME /home/$SUMO_USER/sumo-$SUMO_VERSION

# Install system dependencies.
RUN apt-get update && apt-get -y upgrade && apt-get -qq install \
    apt-utils \
    git \
    g++ \
    make \
    cmake \
    libxerces-c-dev \
    libfox-1.6-0 libfox-1.6-dev \
    python2.7 python2.7-dev \
    libgdal20 libgdal-dev \
    libproj-dev proj-bin proj-data \
    libopenscenegraph-dev \
    libgl2ps-dev

# Download source code
RUN git clone --recursive https://github.com/eclipse/sumo && \
    cd sumo && \
    git fetch origin refs/replace/*:refs/replace/* 

WORKDIR /sumo

# Configure and build SUMO from source.
RUN mkdir -p ./build/cmake-build && \
    cd ./build/cmake-build && \
    cmake ../.. && \
    make -j 8 && \
    make install

RUN adduser $SUMO_USER --disabled-password

# Default action on running the container:
CMD sumo

#################################################################
# Executable Container definition
#################################################################
FROM ubuntu:18.10
#FROM python:2.7-stretch

ENV SUMO_VERSION 1.1.0
ENV SUMO_HOME /usr/local/share/sumo
ENV SUMO_USER sumouser

# Install system dependencies.
#RUN echo "deb http://ftp.debian.org/debian stretch-backports main" >> /etc/apt/sources.list
RUN apt-get update && apt-get -y upgrade && apt-get -qq install \
    apt-utils \
    libfox-1.6-0 \
    python2.7 \
    libgdal20 \
    libxerces-c3.2 \
    proj-bin proj-data  \
    bzip2 \
    curl

RUN ln -s /usr/bin/python2.7 /usr/bin/python

RUN adduser $SUMO_USER --disabled-password
RUN mkdir -p /data

# Extract SUMO executables from Build Container
COPY --from=sumo_builder /usr/local/bin/ /usr/local/bin

# Extract SUMO demo files and tools from Build Container
COPY --from=sumo_builder /usr/local/share/sumo/ /usr/local/share/sumo
RUN chmod -R +x /usr/local/share/sumo/tools

# Copy bash-script for running the simulation as a batch job from local host
COPY sumo.bash /usr/local/share/sumo/bin/startSUMO.bash
RUN chmod +x /usr/local/share/sumo/bin/startSUMO.bash

# Default action on running the container:
ENTRYPOINT ["/bin/bash"]
CMD ["/usr/local/share/sumo/bin/startSUMO.bash"]

#CMD ["sumo"]
