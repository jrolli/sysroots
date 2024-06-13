#!/bin/bash
set -euo pipefail

# Known docker arch: 386, amd64, armv7, arm64v8, ppc64le

export LLVM_SRC_DIR=`realpath $LLVM_SRC_DIR`

echo "Target:        $TARGET"
echo "CMake arch:    $CMAKE_ARCH"
echo "Sysroot path:  $SYSROOT_PATH"
echo
echo "LLVM src dir:  $LLVM_SRC_DIR"

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

REPO_URL="https://cdn-ubi.redhat.com/content/public/ubi/dist/ubi8/8/$CMAKE_ARCH/baseos/os/Packages"
PACKAGE_SUFFIX="$CMAKE_ARCH.rpm"
GLIBC_VERSION="2.28-236.el8_9.13"
KERNEL_PKG="kernel-headers-4.18.0-513.24.1.el8_9.$PACKAGE_SUFFIX"
LIB=lib64

mkdir -p rpmroot
pushd rpmroot
for RPM in "glibc-$GLIBC_VERSION.$PACKAGE_SUFFIX" "glibc-devel-$GLIBC_VERSION.$PACKAGE_SUFFIX" "glibc-headers-$GLIBC_VERSION.$PACKAGE_SUFFIX"
do
      wget $REPO_URL/g/$RPM
      rpm2cpio $RPM | cpio -idmv
done

wget $REPO_URL/k/$KERNEL_PKG
rpm2cpio $KERNEL_PKG | cpio -idmv

mkdir -p $SYSROOT_PATH
cp -r usr/include $SYSROOT_PATH/include

install -D -d $SYSROOT_PATH/$LIB
cp --preserve=all {usr/,}$LIB/*crt*.o            $SYSROOT_PATH/$LIB || true
cp --preserve=all {usr/,}$LIB/ld*                $SYSROOT_PATH/$LIB || true
cp --preserve=all {usr/,}$LIB/libc{.,-,_}*       $SYSROOT_PATH/$LIB || true
cp --preserve=all {usr/,}$LIB/libdl{.,-,_}*      $SYSROOT_PATH/$LIB || true
cp --preserve=all {usr/,}$LIB/librt{.,-,_}*      $SYSROOT_PATH/$LIB || true
cp --preserve=all {usr/,}$LIB/libpthread{.,-,_}* $SYSROOT_PATH/$LIB || true
cp --preserve=all {usr/,}$LIB/libm{,vec}{.,-,_}* $SYSROOT_PATH/$LIB || true
cp --preserve=all {usr/,}$LIB/libresolv{.,-,_}*  $SYSROOT_PATH/$LIB || true

# Add do-nothing endpoints for old init methods
touch $SYSROOT_PATH/$LIB/crtbegin.o
touch $SYSROOT_PATH/$LIB/crtbeginT.o
touch $SYSROOT_PATH/$LIB/crtbeginS.o
touch $SYSROOT_PATH/$LIB/crtend.o
touch $SYSROOT_PATH/$LIB/crtendS.o

for FILE in `grep -lr 'GNU ld script' $SYSROOT_PATH`
do
      sed -i -E 's|(/usr)?/lib(64)?/||g' $FILE
done

popd

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
DESTDIR=$SYSROOT_PATH ninja -C build-builtins install-builtins

sed -e "s|LLVM_SRC_DIR|$LLVM_SRC_DIR|" \
    -e "s|CMAKE_ARCH_VAR|$CMAKE_ARCH|" \
    -e "s|TARGET_TRIPLE|$TARGET|" \
    $SCRIPT_DIR/toolchain.cmake.stage2.in \
    > $SYSROOT_PATH/toolchain.cmake

if [ "$CMAKE_ARCH" = "armv7hl" ]
then
      echo 'set(CMAKE_C_FLAGS_INIT "${CMAKE_C_FLAGS_INIT} -mfloat-abi=hard")' >> $SYSROOT_PATH/toolchain.cmake
      echo 'set(CMAKE_CXX_FLAGS_INIT "${CMAKE_CXX_FLAGS_INIT} -mfloat-abi=hard")' >> $SYSROOT_PATH/toolchain.cmake
fi

cmake -B build-runtimes \
      -S $LLVM_SRC_DIR/runtimes \
      -G Ninja \
      --toolchain=$SYSROOT_PATH/toolchain.cmake \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/ \
      -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind" \
      -DLIBCXX_ENABLE_STATIC=ON \
      -DLIBCXX_ENABLE_SHARED=OFF \
      -DLIBCXXABI_ENABLE_STATIC=ON \
      -DLIBCXXABI_ENABLE_SHARED=OFF \
      -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
      -DLIBUNWIND_ENABLE_STATIC=ON \
      -DLIBUNWIND_ENABLE_SHARED=OFF

ninja -C build-runtimes cxx cxxabi unwind
DESTDIR=$SYSROOT_PATH ninja -C build-runtimes install-cxx install-cxxabi install-unwind

sed -e "s|CMAKE_ARCH_VAR|$CMAKE_ARCH|" -e "s|TARGET_TRIPLE|$TARGET|" -e "s|--static||" $SCRIPT_DIR/toolchain.cmake.final.in > $SYSROOT_PATH/toolchain.cmake

if [ "$CMAKE_ARCH" = "armv7hl" ]
then
      echo 'set(CMAKE_C_FLAGS_INIT "${CMAKE_C_FLAGS_INIT} -mfloat-abi=hard")' >> $SYSROOT_PATH/toolchain.cmake
      echo 'set(CMAKE_CXX_FLAGS_INIT "${CMAKE_CXX_FLAGS_INIT} -mfloat-abi=hard")' >> $SYSROOT_PATH/toolchain.cmake
fi

# cmake -B build-sanitizers \
#       -S $LLVM_SRC_DIR/compiler-rt \
#       -G Ninja \
#       --toolchain=$SYSROOT_PATH/toolchain.cmake \
#       -DCMAKE_BUILD_TYPE=Release \
#       -DCMAKE_INSTALL_PREFIX=/ \
#       -DCOMPILER_RT_USE_LIBCXX=ON \
#       -DCOMPILER_RT_BUILD_BUILTINS=OFF \
#       -DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
#       -DCOMPILER_RT_BUILD_PROFILE=OFF \
#       -DCOMPILER_RT_BUILD_SANITIZERS=ON \
#       -DCOMPILER_RT_BUILD_XRAY=OFF \
#       -DCOMPILER_RT_BUILD_ORC=OFF \
#       -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON

# cmake --build build-sanitizers
# DESTDIR=$SYSROOT_PATH ninja -C build-sanitizers install

sed -e "s|TARGET_TRIPLE|$TARGET|" $SCRIPT_DIR/bashenv.in > $SYSROOT_PATH/bashenv
install --mode=0755 $SCRIPT_DIR/activate.sh $SYSROOT_PATH/activate.sh

pushd $SYSROOT_PATH/..
tar caf $SYSROOT_PATH.tar.xz $(basename $SYSROOT_PATH)
popd

rm -r rpmroot
rm -r build-builtins
rm -r build-runtimes
# rm -r build-sanitizers
rm -r $SYSROOT_PATH
