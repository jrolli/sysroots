FROM debian:12

RUN apt update && \
    apt install -y git xz-utils python3 python3-pip ninja-build && \
    rm -f /usr/lib/python3*/EXTERNALLY-MANAGED && \
    pip install cmake black pylint && \
    mkdir /sources

COPY *.tar.xz /sources

RUN mkdir /toolchain && \
    cd /toolchain && \
    find /sources -name '*.tar.xz' -exec tar xf {} \;

RUN ln -sfv /toolchain/llvm-`uname -m`-linux-glibc2.28 /toolchain/llvm-native

ENV PATH=/toolchain/llvm-native/bin:$PATH
ENV TOOLCHAIN_DIR=/toolchain
