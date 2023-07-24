FROM fedora:37 as builder

ARG CUDA_ARCH=80

ENV DEBIAN_FRONTEND noninteractive

ENV FORCE_UNSAFE_CONFIGURE 1

ENV PATH="/spack/bin:${PATH}"

ENV MPICH_VERSION=4.0.3

ENV CMAKE_VERSION=3.25.2

RUN dnf -y update


RUN dnf -y install cmake gcc git make autogen automake vim \
	                 wget gnupg tar gcc-c++ boost-devel gfortran doxygen libtool \
                   m4 libpciaccess-devel clingo xz bzip2 gzip unzip zlib-devel \
                   ncurses-devel libxml2-devel gsl-devel zstd openblas-devel \
                   flexiblas-devel patch bzip2-devel mpich-devel ninja-build
#
RUN wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_386 && chmod a+x /usr/local/bin/yq
# get latest version of spack
RUN git clone https://github.com/spack/spack.git

# set the location of packages built by spack
RUN spack config add config:install_tree:root:/opt/spack
# set cuda_arch for all packages
# RUN spack config add packages:all:variants:cuda_arch=${CUDA_ARCH}

# find all external packages
RUN spack external find --all --exclude python
# find compilers
RUN spack compiler find
# tweaking the arguments
RUN yq -i '.compilers[0].compiler.flags.fflags = "-fallow-argument-mismatch"' /root/.spack/linux/compilers.yaml

# copy bunch of things from the ci
COPY ci/spack /root/spack-recipe
RUN spack repo add /root/spack-recipe/ --scope user

#RUN spack install libvori
#RUN spack install gsl
#RUN spack install libxsmm
#RUN spack install spglib
#RUN spack install libxc
#RUN spack install libint

# install MPICH
RUN spack install --only=dependencies mpich@${MPICH_VERSION} %gcc
RUN spack install mpich@${MPICH_VERSION} %gcc
RUN spack install intel-oneapi-mkl+cluster
RUN spack install openblas+fortran
RUN spack install py-fypp
RUN spack install dbcsr ^openblas+fortran ^mpich
#RUN spack install dbcsr ^openblas+fortran ^openmpi
RUN spack install dbcsr ^intel-oneapi-mkl+cluster ^mpich
#RUN spack install dbcsr ^intel-oneapi-mkl+cluster ^openmpi


# for the MPI hook
#RUN echo $(spack find --format='{prefix.lib}' mpich) > /etc/ld.so.conf.d/mpich.conf
#RUN ldconfig

ENV SPEC_OPENBLAS="cp2k@master%gcc +libxc +libint smm=libxsmm +spglib +cosma +plumed +libvori +openmp ^openblas+fortran ^dbcsr@develop"
ENV SPEC_MKL="cp2k@master%gcc +sirius +libxc +libint smm=libxsmm +spglib +cosma +plumed +libvori +mpi +openmp ^intel-oneapi-mkl+cluster ^dbcsr@develop"

# install all dependencies
RUN spack install --only=dependencies --fail-fast $SPEC_OPENBLAS ^mpich 
#RUN spack install --only=dependencies --fail-fast $SPEC_OPENBLAS ^openmpi 
RUN spack install --only=dependencies --fail-fast $SPEC_MKL ^mpich 
#RUN spack install --only=dependencies --fail-fast $SPEC_MKL ^openmpi 



