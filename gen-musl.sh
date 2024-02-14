#!/bin/bash
set -euo pipefail

export MUSL_SRC_DIR=`realpath $MUSL_SRC_DIR`
export LLVM_SRC_DIR=`realpath $LLVM_SRC_DIR`
export LINUX_SRC_DIR=`realpath $LINUX_SRC_DIR`

echo "Target:        $TARGET"
echo "Linux arch:    $LINUX_ARCH"
echo "CMake arch:    $CMAKE_ARCH"
echo "Sysroot path:  $SYSROOT_PATH"
echo
echo "musl src dir:        $MUSL_SRC_DIR"
echo "LLVM src dir:        $LLVM_SRC_DIR"
echo "Linux src dir:       $LINUX_SRC_DIR"

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

pushd $LINUX_SRC_DIR
make mrproper
make ARCH=$LINUX_ARCH INSTALL_HDR_PATH=$SYSROOT_PATH headers_install
popd

mkdir -p build-musl
pushd build-musl

CC=clang \
AR=llvm-ar \
RANLIB=llvm-ranlib \
NM=llvm-nm \
LDFLAGS=-fuse-ld=lld \
CFLAGS=--target=$TARGET \
$MUSL_SRC_DIR/configure --prefix=/ --target=$TARGET --disable-shared

make -j
DESTDIR=$SYSROOT_PATH make install -j
rm -r $SYSROOT_PATH/bin

popd

# Add do-nothing endpoints for old init methods
touch $SYSROOT_PATH/lib/crtbegin.o
touch $SYSROOT_PATH/lib/crtbeginT.o
touch $SYSROOT_PATH/lib/crtend.o

sed -e "s|LLVM_SRC_DIR|$LLVM_SRC_DIR|" \
    -e "s|CMAKE_ARCH_VAR|$CMAKE_ARCH|" \
    -e "s|TARGET_TRIPLE|$TARGET|" \
    $SCRIPT_DIR/toolchain.cmake.stage1.in \
    > $SYSROOT_PATH/toolchain.cmake

cmake -B build-builtins \
      -S $LLVM_SRC_DIR/compiler-rt \
      -G Ninja \
      --toolchain=$SYSROOT_PATH/toolchain.cmake \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/ \
      -DCOMPILER_RT_BUILD_BUILTINS=ON \
      -DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
      -DCOMPILER_RT_BUILD_PROFILE=OFF \
      -DCOMPILER_RT_BUILD_SANITIZERS=OFF \
      -DCOMPILER_RT_BUILD_XRAY=OFF \
      -DCOMPILER_RT_EXCLUDE_ATOMIC_BUILTIN=OFF \
      -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON

cmake --build build-builtins --target builtins

install -D -d $SYSROOT_PATH/lib/linux
find build-builtins -name libclang_rt.builtins-*.a -exec install {} $SYSROOT_PATH/lib/linux \;

sed -e "s|LLVM_SRC_DIR|$LLVM_SRC_DIR|" \
    -e "s|CMAKE_ARCH_VAR|$CMAKE_ARCH|" \
    -e "s|TARGET_TRIPLE|$TARGET|" \
    $SCRIPT_DIR/toolchain.cmake.stage2.in \
    > $SYSROOT_PATH/toolchain.cmake

cmake -B build-runtimes \
      -S $LLVM_SRC_DIR/runtimes \
      -G Ninja \
      --toolchain=$SYSROOT_PATH/toolchain.cmake \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/ \
      -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind" \
      -DLIBCXX_HAS_MUSL_LIBC=ON \
      -DLIBCXX_ENABLE_STATIC=ON \
      -DLIBCXX_ENABLE_SHARED=OFF \
      -DLIBCXXABI_ENABLE_STATIC=ON \
      -DLIBCXXABI_ENABLE_SHARED=OFF \
      -DLIBUNWIND_ENABLE_STATIC=ON \
      -DLIBUNWIND_ENABLE_SHARED=OFF

ninja -C build-runtimes cxx cxxabi unwind
DESTDIR=$SYSROOT_PATH ninja -C build-runtimes install-cxx install-cxxabi install-unwind

pushd build-musl

TMP_LDFLAGS="-fuse-ld=lld"

if [ "$LINUX_ARCH" = "mips" ]
then
      TMP_LDFLAGS="$TMP_LDFLAGS -Wl,--hash-style=sysv"
fi

CC=clang \
AR=llvm-ar \
RANLIB=llvm-ranlib \
NM=llvm-nm \
LIBCC="--rtlib=compiler-rt $SYSROOT_PATH/lib/linux/libclang_rt.builtins-$CMAKE_ARCH.a" \
LDFLAGS="$TMP_LDFLAGS" \
CFLAGS=--target=$TARGET \
$MUSL_SRC_DIR/configure --prefix=/ --target=$TARGET

make -j
DESTDIR=$SYSROOT_PATH make install -j
rm -r $SYSROOT_PATH/bin

popd

touch $SYSROOT_PATH/lib/crtbeginS.o
touch $SYSROOT_PATH/lib/crtendS.o

sed -e "s|CMAKE_ARCH_VAR|$CMAKE_ARCH|" -e "s|TARGET_TRIPLE|$TARGET|" $SCRIPT_DIR/toolchain.cmake.final.in > $SYSROOT_PATH/toolchain.cmake
sed -e "s|TARGET_TRIPLE|$TARGET|" $SCRIPT_DIR/bashenv.in > $SYSROOT_PATH/bashenv
install --mode=0755 $SCRIPT_DIR/activate.sh $SYSROOT_PATH/activate.sh

pushd $SYSROOT_PATH/..
tar caf $SYSROOT_PATH.tar.xz $(basename $SYSROOT_PATH)
popd

rm -r build-musl
rm -r build-builtins
rm -r build-runtimes
rm -r $SYSROOT_PATH
