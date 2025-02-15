#
# Build this docker with
#
#     docker build -t dlite .
#
# To run this docker in an interactive bash shell, do
#
#     docker run -i -t dlite
#
# A more realistic way to use this docker is to put the following
# into a shell script (called dlite)
#
#     #!/bin/sh
#     docker run --rm -it --user="$(id -u):$(id -g)" --net=none \
#         -v "$PWD":/data dlite "$@"
#
# To run the getuuid tool inside the docker image, you could then do
#
#     dlite dlite-getuuid <string>
#
# To run a python script in current directory inside the docker image
#
#     dlite python /data/script.py
#


##########################################
# Stage: install dependencies
##########################################
FROM ubuntu:20.04 AS dependencies
RUN apt-get -qq update --fix-missing

# Default cmake is 3.10.2. We need at least 3.11...
# Install tools for adding cmake
RUN apt-get install -qq -y \
    apt-transport-https \
    ca-certificates \
    gnupg \
    software-properties-common \
    wget

# Obtain signing key
RUN wget -O - \
     https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | \
     apt-key add -

# Add Kitware repo
RUN apt-add-repository 'deb https://apt.kitware.com/ubuntu/ focal bionic main'
RUN apt update

# Ensure that our keyring stays up to date
RUN apt-get install kitware-archive-keyring

# Install dependencies
RUN apt-get install -qq -y --fix-missing \
        cmake \
        cmake-curses-gui \
        cppcheck \
        doxygen \
        gcc \
        gdb \
        gfortran \
        git \
        g++ \
        libhdf5-dev \
        libjansson-dev \
        librdf0-dev \
        librasqal3-dev \
        libraptor2-dev \
        make \
        python3-dev \
        python3-pip \
        swig4.0 \
        rpm \
        librpmbuild8 \
        dpkg \
    && rm -rf /var/lib/apt/lists/*


# Install Python packages
COPY requirements.txt .
RUN pip3 install --trusted-host files.pythonhosted.org \
    --upgrade pip -r requirements.txt


##########################################
# Stage: build
##########################################
FROM dependencies AS build

# Create and become a normal user
RUN useradd -ms /bin/bash user
USER user

# Setup dlite
RUN mkdir -p /home/user/sw/dlite
COPY --chown=user:user bindings /home/user/sw/dlite/bindings
COPY --chown=user:user cmake /home/user/sw/dlite/cmake
COPY --chown=user:user doc /home/user/sw/dlite/doc
COPY --chown=user:user examples /home/user/sw/dlite/examples
COPY --chown=user:user src /home/user/sw/dlite/src
COPY --chown=user:user storages /home/user/sw/dlite/storages
COPY --chown=user:user tools /home/user/sw/dlite/tools
COPY --chown=user:user CMakeLists.txt LICENSE README.md /home/user/sw/dlite/
WORKDIR /home/user/sw/dlite

# Perform static code checking
# FIXME - test_tgen.c produce a lot of false positives
RUN cppcheck . \
    --language=c -q --force --error-exitcode=2 --inline-suppr -i build \
    -i src/utils/tests/test_tgen.c

# Build dlite
RUN mkdir build
WORKDIR /home/user/sw/dlite/build
RUN cmake .. -DFORCE_EXAMPLES=ON -DALLOW_WARNINGS=ON -DWITH_FORTRAN=ON \
        -DCMAKE_INSTALL_PREFIX=/tmp/dlite-install
RUN make

# Create distributable packages
RUN cpack
RUN cpack -G DEB
RUN cpack -G RPM

# Install
USER root
RUN make install

# Skip postgresql tests since we haven't set up the server and
# static-code-analysis since it is already done.
# TODO - set up postgresql server and run the postgresql tests...
USER user
RUN ctest -E "(postgresql|static-code-analysis)" || \
    ctest -E "(postgresql|static-code-analysis)" \
        --rerun-failed --output-on-failure -VV

# Set DLITE_USE_BUILD_ROOT in case we want to test dlite from the build dir
ENV DLITE_USE_BUILD_ROOT=YES


#########################################
# Stage: develop
#########################################
FROM build AS develop
ENV PATH=/tmp/dlite-install/bin:$PATH
ENV LD_LIBRARY_PATH=/tmp/dlite-install/lib:$LD_LIBRARY_PATH
ENV DLITE_ROOT=/tmp/dlite-install
ENV PYTHONPATH=/tmp/dlite-install/lib/python3.8/site-packages:$PYTHONPATH


##########################################
# Stage: final slim image
##########################################
FROM python:3.8.3-slim-buster AS production

RUN apt -qq update \
  && apt install -y -qq --fix-missing librdf0 \
  && rm -rf /var/lib/apt/lists/*
# Copy needed dlite files and libraries to slim image
COPY --from=build /tmp/dlite-install /usr/local
COPY --from=build /usr/lib/x86_64-linux-gnu/libjansson.so* /usr/local/lib/
COPY --from=build /usr/lib/x86_64-linux-gnu/libhdf5*.so* /usr/local/lib/
COPY --from=build /usr/lib/x86_64-linux-gnu/libsz.so* /usr/local/lib/
COPY --from=build /usr/lib/x86_64-linux-gnu/libaec.so* /usr/local/lib/
COPY --from=build /usr/lib/x86_64-linux-gnu/libm.so* /usr/local/lib/
RUN pip install --upgrade pip \
    --trusted-host files.pythonhosted.org \
    numpy \
    PyYAML \
    psycopg2-binary

RUN useradd -ms /bin/bash user
USER user
WORKDIR /home/user
ENV LD_LIBRARY_PATH=/usr/local/lib
ENV DLITE_ROOT=/usr/local

# Default command
CMD ["/bin/bash"]
