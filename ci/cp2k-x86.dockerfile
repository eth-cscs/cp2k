FROM docker.io/ubuntu22.04 as builder

ARG CUDA_ARCH=80

ENV DEBIAN_FRONTEND noninteractive

ENV FORCE_UNSAFE_CONFIGURE 1

ENV PATH="/spack/bin:${PATH}"

ENV MPICH_VERSION=4.0.3
ENV CMAKE_VERSION=3.25.2
RUN apt-get update -qq
RUN apt-get install -qq --no-install-recommends autoconf autogen automake autotools-dev bzip2 ca-certificates g++ gcc gfortran git less libtool libtool-bin make nano patch pkg-config python3 unzip wget xxd zlib1g-dev cmake gnupg m4 xz-utils libssl-dev libssh-dev 
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

# install MPICH
RUN spack install --only=dependencies mpich@${MPICH_VERSION} %gcc
RUN spack install mpich@${MPICH_VERSION} %gcc

#install openmpi
RUN spack install openmpi

#install few dependencies.
RUN spack install intel-oneapi-mkl+cluster
RUN spack install openblas+fortran
RUN spack install libxsmm
RUN spack install libxc
RUN spack install gsl
RUN spack install py-fypp
RUN spack install spglib
RUN spack install fftw
RUN spack install fftw+openmp
RUN spack install libvori

RUN spack clean -dfs
# for the MPI hook
RUN echo $(spack find --format='{prefix.lib}' mpich) > /etc/ld.so.conf.d/mpich.conf
RUN ldconfig

# full spec 
ENV SPEC_OPENBLAS="cp2k@master%gcc +libxc +libint +sirius +elpa +plumed +pexsi smm=libxsmm +spglib +cosma +mpi +openmp ^openblas+fortran ^cosma+scalapack+sharedsirius"
ENV SPEC_MKL="cp2k@master%gcc +libxc +libint +sirius +elpa +plumed +pexsi smm=libxsmm +spglib +cosma +mpi +openmp ^intel-oneapi-mkl+cluster ^cosma+scalapack+shared"

# NB : the next 4 lines can be removed normally but it is still better to create
  additional stages in case of a build failure of cp2k. 

# install all dependencies
RUN spack install --only=dependencies --fail-fast $SPEC_OPENBLAS ^mpich@${MPICH_VERSION} 
RUN spack install --only=dependencies --fail-fast $SPEC_OPENBLAS ^openmpi 
RUN spack install --only=dependencies --fail-fast $SPEC_MKL ^mpich@${MPICH_VERSION}
RUN spack install --only=dependencies --fail-fast $SPEC_MKL ^openmpi 

# MPICH has a specific version for CRAY systems
RUN spack install --fail-fast $SPEC_OPENBLAS ^mpich@${MPICH_VERSION}
RUN spack install --fail-fast $SPEC_OPENBLAS ^openmpi 
RUN spack install --fail-fast $SPEC_MKL ^mpich@${MPICH_VERSION}
RUN spack install --fail-fast $SPEC_MKL ^openmpi 
RUN spack clean -dfs

