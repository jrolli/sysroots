LABEL org.opencontainers.image.description "Pre-bundled syroots and toolchain"

FROM debian:12-slim

RUN apt update && \
    apt install -y --no-install-recommends git \
                                           xz-utils \
                                           python3 \
                                           python3-pip \
                                           ninja-build && \
    rm -rf /var/lib/apt/lists/* && \
    rm -f /usr/lib/python3*/EXTERNALLY-MANAGED && \
    pip install cmake black pylint && \
    mkdir /sources

COPY *.tar.xz /sources

RUN mkdir /toolchain && \
    cd /toolchain && \
    find /sources -name '*.tar.xz' \! -name 'llvm-*' -exec tar xf {} \;

RUN cd /toolchain && \
    tar xf /sources/llvm-`uname -m`-linux-glibc2.28.tar.xz && \
    ln -sfv /toolchain/llvm-`uname -m`-linux-glibc2.28 /toolchain/llvm-native

ENV PATH=/toolchain/llvm-native/bin:$PATH
ENV TOOLCHAIN_DIR=/toolchain
