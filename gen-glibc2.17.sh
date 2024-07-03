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

case $CMAKE_ARCH in
      x86_64)
            REPO_URL="http://mirror.centos.org/centos/7/os/x86_64/Packages"
            PACKAGE_SUFFIX="el7.x86_64.rpm"
            KERNEL_PKG="kernel-headers-3.10.0-1160.$PACKAGE_SUFFIX"
            LIB=lib64
      ;;

      i686)
            REPO_URL="http://mirror.centos.org/altarch/7/os/i386/Packages"
            PACKAGE_SUFFIX="el7.i686.rpm"
            KERNEL_PKG="kernel-headers-3.10.0-1160.2.2.el7.centos.plus.i686.rpm"
            LIB=lib
      ;;

      aarch64)
            REPO_URL="http://mirror.centos.org/altarch/7/os/aarch64/Packages"
            PACKAGE_SUFFIX="el7.aarch64.rpm"
            KERNEL_PKG="kernel-headers-4.18.0-193.28.1.$PACKAGE_SUFFIX"
            LIB=lib64
      ;;

      armv7hl)
            REPO_URL="http://mirror.centos.org/altarch/7/os/armhfp/Packages"
            PACKAGE_SUFFIX="el7.armv7hl.rpm"
            KERNEL_PKG="kernel-headers-5.4.28-200.$PACKAGE_SUFFIX"
            LIB=lib
      ;;

      powerpc64)
            REPO_URL="http://mirror.centos.org/altarch/7/os/ppc64/Packages"
            PACKAGE_SUFFIX="el7.ppc64.rpm"
            KERNEL_PKG="kernel-headers-3.10.0-1160.$PACKAGE_SUFFIX"
            LIB=lib64
      ;;

      powerpc64le)
            REPO_URL="http://mirror.centos.org/altarch/7/os/ppc64le/Packages"
            PACKAGE_SUFFIX="el7.ppc64le.rpm"
            KERNEL_PKG="kernel-headers-3.10.0-1160.$PACKAGE_SUFFIX"
            LIB=lib64
      ;;

      *)
            echo "ERROR: unsupported architecture"
            exit 1
      ;;
esac

mkdir -p rpmroot
pushd rpmroot
for RPM in "glibc-2.17-317.$PACKAGE_SUFFIX" "glibc-devel-2.17-317.$PACKAGE_SUFFIX" "glibc-headers-2.17-317.$PACKAGE_SUFFIX" "$KERNEL_PKG"
do
      curl -O $REPO_URL/$RPM
      rpm2cpio $RPM | cpio -idmv
done

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
touch $SYSROOT_PATH/$LIB/crtbeginS.o
touch $SYSROOT_PATH/$LIB/crtbeginT.o
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

install -D -d $SYSROOT_PATH/lib/linux
find build-builtins -name libclang_rt.*.a -exec install {} $SYSROOT_PATH/lib/linux \;

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

sed -e "s|TARGET_TRIPLE|$TARGET|" $SCRIPT_DIR/bashenv.in > $SYSROOT_PATH/bashenv
install --mode=0755 $SCRIPT_DIR/activate.sh $SYSROOT_PATH/activate.sh

pushd $SYSROOT_PATH/..
tar caf $SYSROOT_PATH.tar.xz $(basename $SYSROOT_PATH)
popd

rm -r rpmroot
rm -r build-builtins
rm -r build-runtimes
rm -r $SYSROOT_PATH
