ARG BASE_IMAGE
FROM $BASE_IMAGE

ARG SPECDEV
ARG CMAKE_ARG

# show the spack's spec
#RUN spack spec -I $SPECDEV

RUN spack env create --with-view /opt/cp2k cp2k-env
RUN spack -e cp2k-env add $SPECDEV

# copy source files of the pull request into container
COPY . /cp2k-src

# build cp2k
RUN spack --color always -e cp2k-env dev-build -q --source-path /cp2k-src $SPECDEV 

#-- cd /opt/src/cp2k-src && \
#mkdir build && \
#cd build && \
#cmake $CMAKE_ARG .. \
#make -j16 \
#make install

# we need a fixed name for the build directory
# here is a hacky workaround to link ./spack-build-{hash} to ./spack-build
RUN cd /cp2k-src && ln -s $(find . -name "spack-build-*" -type d) spack-build
