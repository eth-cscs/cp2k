FROM docker.io/nvidia/cuda:12.1.0-devel-ubuntu22.04 as builder

ARG CUDA_ARCH=80

ENV DEBIAN_FRONTEND noninteractive

ENV FORCE_UNSAFE_CONFIGURE 1

ENV PATH="/spack/bin:${PATH}"

ENV MPICH_VERSION=3.4.3

ENV LIBRARY_PATH=$LIBRARY_PATH:/usr/local/cuda/lib64/stubs

#ENV CMAKE_VERSION=3.26.3

RUN apt-get -y update

RUN apt-get install -y apt-utils

# install basic tools
RUN apt-get install -y --no-install-recommends gcc g++ gfortran clang libomp-14-dev git make unzip file \
  vim wget pkg-config python3-pip python3-dev cython3 python3-pythran curl tcl m4 cpio automake meson \
  xz-utils patch patchelf apt-transport-https ca-certificates gnupg software-properties-common perl tar bzip2 cmake ninja-build openssh-client libssl-dev libbz2-dev autotools-dev autoconf libgsl-dev 
# install CMake
#RUN wget https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz -O cmake.tar.gz && \
#    tar zxvf cmake.tar.gz --strip-components=1 -C /usr

# get latest version of spack
RUN git clone https://github.com/spack/spack.git

# set the location of packages built by spack
RUN spack config add config:install_tree:root:/opt/local
# set cuda_arch for all packages
RUN spack config add packages:all:variants:cuda_arch=${CUDA_ARCH}

# find all external packages
RUN spack external find --all

# find compilers
RUN spack compiler find

# install yq (utility to manipulate the yaml files)
RUN wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_386 && chmod a+x /usr/local/bin/yq

# change the fortran compilers: for gcc the gfortran is already properly set and the change has no effect; add it for clang
RUN yq -i '.compilers[0].compiler.flags.fflags = "-fallow-argument-mismatch"' /root/.spack/linux/compilers.yaml

# copy bunch of things from the ci
COPY ci/spack /root/spack-recipe
RUN spack repo add /root/spack-recipe/ --scope user

RUN spack install libvori
RUN spack install py-fypp
# for the MPI hook
RUN echo $(spack find --format='{prefix.lib}' mpich) > /etc/ld.so.conf.d/mpich.conf
RUN ldconfig

ENV SPEC_OPENBLAS="cp2k@master%gcc +sirius +elpa +libxc +libint smm=libxsmm +spglib +cosma +cuda cuda_arch=80 +pexsi +plumed +libvori +openmp ^openblas+fortran ^dbcsr@2.6.0+cuda~shared+mpi cuda_arch=70 ^cosma+shared~tests~apps+cuda"
ENV SPEC_MKL="cp2k@master%gcc +sirius +elpa +libxc +libint smm=libxsmm +spglib +cosma +cuda cuda_arch=80 +pexsi +plumed +libvori +mpi +openmp ^intel-oneapi-mkl+cluster ^dbcsr@2.6.0+cuda~shared+mpi cuda_arch=80 ^cosma+shared~tests~apps+cuda"

# install all dependencies
RUN spack install --only=dependencies --fail-fast $SPEC_OPENBLAS ^mpich@${MPICH_VERSION}
#RUN spack install --only=dependencies --fail-fast $SPEC_OPENBLAS ^openmpi 
RUN spack install --only=dependencies --fail-fast $SPEC_MKL ^mpich@${MPICH_VERSION}
#RUN spack install --only=dependencies --fail-fast $SPEC_MKL ^openmpi 
