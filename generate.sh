#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

echo "LLVM_SRC_DIR:  ${LLVM_SRC_DIR:=`pwd`/../llvm-project}"
echo "MUSL_SRC_DIR:  ${MUSL_SRC_DIR:=`pwd`/../musl}"
echo "LINUX_SRC_DIR: ${LINUX_SRC_DIR:=`pwd`/../linux}"

export LLVM_SRC_DIR
export MUSL_SRC_DIR
export LINUX_SRC_DIR

x86_64-linux-glibc2.28 () {
    TARGET=x86_64-linux-gnu \
    CMAKE_ARCH=x86_64 \
    SYSROOT_PATH=`pwd`/x86_64-linux-glibc2.28 \
    $SCRIPT_DIR/gen-glibc2.28.sh
}

aarch64-linux-glibc2.28 () {
    TARGET=aarch64-linux-gnu \
    CMAKE_ARCH=aarch64 \
    SYSROOT_PATH=`pwd`/aarch64-linux-glibc2.28 \
    $SCRIPT_DIR/gen-glibc2.28.sh
}

x86_64-linux-glibc2.17 () {
    TARGET=x86_64-linux-gnu \
    CMAKE_ARCH=x86_64 \
    SYSROOT_PATH=`pwd`/x86_64-linux-glibc2.17 \
    $SCRIPT_DIR/gen-glibc2.17.sh
}

i686-linux-glibc2.17 () {
    TARGET=i686-linux-gnu \
    CMAKE_ARCH=i686 \
    SYSROOT_PATH=`pwd`/i686-linux-glibc2.17 \
    $SCRIPT_DIR/gen-glibc2.17.sh
}

aarch64-linux-glibc2.17 () {
    TARGET=aarch64-linux-gnu \
    CMAKE_ARCH=aarch64 \
    SYSROOT_PATH=`pwd`/aarch64-linux-glibc2.17 \
    $SCRIPT_DIR/gen-glibc2.17.sh
}

armv7hl-linux-glibc2.17 () {
    TARGET=armv7hl-linux-gnu \
    CMAKE_ARCH=armv7hl \
    SYSROOT_PATH=`pwd`/armv7hl-linux-glibc2.17 \
    $SCRIPT_DIR/gen-glibc2.17.sh
}

powerpc64-linux-glibc2.17 () {
    TARGET=powerpc64-linux-gnu \
    CMAKE_ARCH=powerpc64 \
    SYSROOT_PATH=`pwd`/powerpc64-linux-glibc2.17 \
    $SCRIPT_DIR/gen-glibc2.17.sh
}

powerpc64le-linux-glibc2.17 () {
    TARGET=powerpc64le-linux-gnu \
    CMAKE_ARCH=powerpc64le \
    SYSROOT_PATH=`pwd`/powerpc64le-linux-glibc2.17 \
    $SCRIPT_DIR/gen-glibc2.17.sh
}

x86_64-linux-musl () {
    TARGET=x86_64-linux-musl \
    LINUX_ARCH=x86 \
    CMAKE_ARCH=x86_64 \
    SYSROOT_PATH=`pwd`/x86_64-linux-musl \
    $SCRIPT_DIR/gen-musl.sh
}

i386-linux-musl () {
    TARGET=i386-linux-musl \
    LINUX_ARCH=x86 \
    CMAKE_ARCH=i386 \
    SYSROOT_PATH=`pwd`/i386-linux-musl \
    $SCRIPT_DIR/gen-musl.sh
}

aarch64-linux-musl () {
    TARGET=aarch64-linux-musl \
    LINUX_ARCH=arm64 \
    CMAKE_ARCH=aarch64 \
    SYSROOT_PATH=`pwd`/aarch64-linux-musl \
    $SCRIPT_DIR/gen-musl.sh
}

armv7-linux-musl () {
    TARGET=armv7-linux-musl \
    LINUX_ARCH=arm \
    CMAKE_ARCH=arm \
    SYSROOT_PATH=`pwd`/armv7-linux-musl \
    $SCRIPT_DIR/gen-musl.sh
}

mips-linux-musl () {
    TARGET=mips-linux-musl \
    LINUX_ARCH=mips \
    CMAKE_ARCH=mips \
    SYSROOT_PATH=`pwd`/mips-linux-musl \
    $SCRIPT_DIR/gen-musl.sh
}

mipsel-linux-musl () {
    TARGET=mipsel-linux-musl \
    LINUX_ARCH=mips \
    CMAKE_ARCH=mipsel \
    SYSROOT_PATH=`pwd`/mipsel-linux-musl \
    $SCRIPT_DIR/gen-musl.sh
}

mips64-linux-musl () {
    TARGET=mips64-linux-musl \
    LINUX_ARCH=mips \
    CMAKE_ARCH=mips64 \
    SYSROOT_PATH=`pwd`/mips64-linux-musl \
    $SCRIPT_DIR/gen-musl.sh
}

mips64el-linux-musl () {
    TARGET=mips64el-linux-musl \
    LINUX_ARCH=mips \
    CMAKE_ARCH=mips64el \
    SYSROOT_PATH=`pwd`/mips64el-linux-musl \
    $SCRIPT_DIR/gen-musl.sh
}

powerpc64-linux-musl () {
    TARGET=powerpc64-linux-musl \
    LINUX_ARCH=powerpc \
    CMAKE_ARCH=powerpc64 \
    SYSROOT_PATH=`pwd`/powerpc64-linux-musl \
    $SCRIPT_DIR/gen-musl.sh
}

powerpc64le-linux-musl () {
    TARGET=powerpc64le-linux-musl \
    LINUX_ARCH=powerpc \
    CMAKE_ARCH=powerpc64le \
    SYSROOT_PATH=`pwd`/powerpc64le-linux-musl \
    $SCRIPT_DIR/gen-musl.sh
}

powerpc-linux-musl () {
    TARGET=powerpc-linux-musl \
    LINUX_ARCH=powerpc \
    CMAKE_ARCH=powerpc \
    SYSROOT_PATH=`pwd`/powerpc-linux-musl \
    $SCRIPT_DIR/gen-musl.sh
}

if [ $# -ne 0 ]
then
    for tgt in "$@"
    do
        $tgt
    done
else
    x86_64-linux-glibc2.28
    aarch64-linux-glibc2.28
    x86_64-linux-glibc2.17
    i686-linux-glibc2.17
    aarch64-linux-glibc2.17
    armv7hl-linux-glibc2.17
    powerpc64-linux-glibc2.17
    powerpc64le-linux-glibc2.17
    x86_64-linux-musl
    i386-linux-musl
    aarch64-linux-musl
    armv7-linux-musl
    mips-linux-musl
    mipsel-linux-musl
    mips64-linux-musl
    mips64el-linux-musl
    powerpc-linux-musl
    powerpc64-linux-musl
    powerpc64le-linux-musl
fi
