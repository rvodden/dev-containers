ARG UBUNTU_VERSION=22.04

FROM ubuntu:${UBUNTU_VERSION} AS baseimage
ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-c"]

RUN apt update && apt install -y build-essential g++ git libgmp-dev libmpfr-dev \
    libmpc-dev libisl-dev libzstd-dev binutils gzip bzip2 tar perl \
    python3 ninja-build libssl-dev zlib1g-dev file \
    flex bison zip python-is-python3
RUN apt-get install -y --no-install-recommends wget

FROM baseimage AS vscodeimage
COPY --chmod=0777 download_vscode.sh /root/download_vscode.sh
RUN /root/download_vscode.sh
ENV PATH="$PATH:/root/.vscode-server/bin"
RUN /root/.vscode-server/bin/code-server --install-extension ms-vscode.cpptools-extension-pack
RUN /root/.vscode-server/bin/code-server --install-extension ms-vscode.cmake-tools
RUN /root/.vscode-server/bin/code-server --install-extension EditorConfig.EditorConfig

FROM baseimage AS cmakeimage
ARG CMAKE_VERSION=3.26.4
RUN wget -q https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz
RUN tar -xzf cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz -C /opt
RUN mv /opt/cmake-${CMAKE_VERSION}-linux-x86_64 /opt/cmake
ENV PATH="$PATH:/opt/cmake/bin"

FROM cmakeimage AS moldimage
ARG MOLD_VERSION=1.11.0
ENV PATH="$PATH:/opt/cmake/bin"
RUN git clone https://github.com/rui314/mold.git --branch v${MOLD_VERSION} --single-branch --depth=1 
RUN mkdir -p mold/build
WORKDIR /mold/build
RUN cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/mold .. -GNinja
RUN cmake --build . 
RUN cmake --install . 
ENV PATH="$PATH:/opt/mold/bin"

FROM cmakeimage AS ninjaimage
ARG NINJA_VERSION=1.11.1
RUN wget -q https://github.com/ninja-build/ninja/releases/download/v1.11.1/ninja-linux.zip
RUN unzip ninja-linux.zip
RUN mkdir -p /opt/ninja/bin
RUN mv /ninja /opt/ninja/bin
WORKDIR /

FROM baseimage AS gccimage
ARG GCC_MAJOR_VERSION=13
RUN git clone git://gcc.gnu.org/git/gcc.git --branch releases/gcc-${GCC_MAJOR_VERSION} --single-branch --depth=1
RUN mkdir gcc-build
WORKDIR /gcc-build
RUN ../gcc/configure --host=x86_64-pc-linux-gnu --prefix=/opt/gcc/ \
    --disable-multilib --with-system-zlib --enable-default-pie --enable-default-ssp --disable-fixincludes \
    --enable-languages=c,c++
RUN make -j20 && make install
WORKDIR /

FROM ubuntu:${UBUNTU_VERSION} AS gdbimage
ARG GDB_VERSION=13.2
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update
RUN apt install -y make libc-dev libgmp-dev libmpfr-dev libmpc-dev libisl-dev \
    libzstd-dev binutils gzip bzip2 wget libreadline-dev texinfo
COPY --from=gccimage /opt/gcc /opt/gcc
ENV PATH="/opt/gcc/bin:$PATH"
COPY 00_x86_64-pc-linux.conf /etc/ld.so.conf.d/00_x86_64-pc-linux.conf
RUN ldconfig
WORKDIR /
RUN wget -q https://ftp.gnu.org/gnu/gdb/gdb-${GDB_VERSION}.tar.gz
RUN tar -xvf gdb-${GDB_VERSION}.tar.gz
RUN mkdir gdb-build
WORKDIR /gdb-build
RUN ../gdb-${GDB_VERSION}/configure --prefix=/opt/gdb --enable-targets=x86_64-pc-linux --enable-tui
RUN make -j20 && make install
WORKDIR /

FROM ubuntu:${UBUNTU_VERSION} AS x86_64-pc-ubuntu-gcc
ARG USERNAME=hadev
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update
RUN apt install -y libc-dev libgmp-dev libmpfr-dev libmpc-dev libisl-dev \
    libzstd-dev binutils gzip bzip2 sudo git python3 python-is-python3 \
    pkg-config
COPY --from=moldimage /opt/mold /opt/mold
COPY --from=cmakeimage /opt/cmake /opt/cmake
COPY --from=ninjaimage /opt/ninja /opt/ninja
COPY --from=gccimage /opt/gcc /opt/gcc
COPY --from=gdbimage /opt/gdb /opt/gdb
ENV PATH="/opt/mold/bin:/opt/cmake/bin:/opt/gcc/bin:/opt/ninja/bin:/opt/gdb/bin:$PATH"
COPY 00_x86_64-pc-linux.conf /etc/ld.so.conf.d/00_x86_64-pc-linux.conf
RUN ldconfig
COPY CMakeToolchain-base.txt /CMakeToolchain-base.txt
COPY CMakeToolchain-gcc13.txt /CMakeToolchain.txt
WORKDIR /

RUN groupadd --gid $USER_GID $USERNAME 
RUN useradd --uid $USER_UID --gid $USER_GID -m $USERNAME
RUN chsh $USERNAME -s /bin/bash
RUN echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME
RUN chmod 0440 /etc/sudoers.d/$USERNAME

COPY --from=vscodeimage --chown=${USERNAME}:${USERNAME} /root/.vscode-server /home/$USERNAME/.vscode-server
USER ${USERNAME}

FROM x86_64-pc-ubuntu-gcc AS x86_64-pc-ubuntu-gcc-x11
USER root
RUN apt install -y gnome-desktop-testing libasound2-dev libpulse-dev \
    libaudio-dev libjack-dev libsndio-dev libx11-dev libxext-dev \
    libxrandr-dev libxcursor-dev libxfixes-dev libxi-dev libxss-dev \
    libxkbcommon-dev libdrm-dev libgbm-dev libgl1-mesa-dev libgles2-mesa-dev \
    libegl1-mesa-dev libdbus-1-dev libibus-1.0-dev libudev-dev fcitx-libs-dev \
    libpipewire-0.3-dev libwayland-dev libdecor-0-dev
# this next line is required as something is borked in mesa
# see conversation here: https://bugs.launchpad.net/cloud-images/+bug/2007555
RUN apt install -y --allow-downgrades libgl1-mesa-dri=22.0.1-1ubuntu2 \
    libglx-mesa0=22.0.1-1ubuntu2 \
    libgl1-mesa-glx=22.0.1-1ubuntu2 \
    libglapi-mesa=22.0.1-1ubuntu2 \
    libgbm1=22.0.1-1ubuntu2 \
    libegl-mesa0=22.0.1-1ubuntu2 \
    libgl1-mesa-dri=22.0.1-1ubuntu2 \
    libglx-mesa0=22.0.1-1ubuntu2
USER hadev

FROM baseimage AS iccimage
RUN apt install -y software-properties-common
RUN wget https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB
RUN apt-key add GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB
RUN rm GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB
RUN add-apt-repository "deb https://apt.repos.intel.com/oneapi all main"
RUN apt install -y intel-basekit
COPY CMakeToolchain-icc.txt /CMakeToolchain.txt

FROM iccimage AS x86_64-pc-ubuntu-icc
ARG USERNAME=hadev
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update
RUN apt install -y libc-dev libgmp-dev libmpfr-dev libmpc-dev libisl-dev \
    libzstd-dev binutils gzip bzip2 sudo git python3 python-is-python3 \
    pkg-config
COPY --from=cmakeimage /opt/cmake /opt/cmake
COPY --from=ninjaimage /opt/ninja /opt/ninja
ENV PATH="/opt/cmake/bin:/opt/ninja/bin:$PATH"
COPY --chown=root:root .bashrc /root/.bashrc
COPY --chown=hadev:hadev .bashrc /home/hadev/.bashrc
WORKDIR /

RUN groupadd --gid $USER_GID $USERNAME 
RUN useradd --uid $USER_UID --gid $USER_GID -m $USERNAME
RUN chsh $USERNAME -s /bin/bash
RUN echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME
RUN chmod 0440 /etc/sudoers.d/$USERNAME

FROM x86_64-pc-ubuntu-icc AS x86_64-pc-ubuntu-icc-x11
USER root
RUN apt install -y gnome-desktop-testing libasound2-dev libpulse-dev \
    libaudio-dev libjack-dev libsndio-dev libx11-dev libxext-dev \
    libxrandr-dev libxcursor-dev libxfixes-dev libxi-dev libxss-dev \
    libxkbcommon-dev libdrm-dev libgbm-dev libgl1-mesa-dev libgles2-mesa-dev \
    libegl1-mesa-dev libdbus-1-dev libibus-1.0-dev libudev-dev fcitx-libs-dev \
    libpipewire-0.3-dev libwayland-dev libdecor-0-dev
# this next line is required as something is borked in mesa
# see conversation here: https://bugs.launchpad.net/cloud-images/+bug/2007555
RUN apt install -y --allow-downgrades libgl1-mesa-dri=22.0.1-1ubuntu2 \
    libglx-mesa0=22.0.1-1ubuntu2 \
    libgl1-mesa-glx=22.0.1-1ubuntu2 \
    libglapi-mesa=22.0.1-1ubuntu2 \
    libgbm1=22.0.1-1ubuntu2 \
    libegl-mesa0=22.0.1-1ubuntu2 \
    libgl1-mesa-dri=22.0.1-1ubuntu2 \
    libglx-mesa0=22.0.1-1ubuntu2
USER hadev