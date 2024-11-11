#!/bin/bash
set -euo pipefail

echo "Target:          $TARGET"
echo "CMake arch:      $CMAKE_ARCH"
echo "Sysroot path:    $SYSROOT_PATH"
echo "FreeBSD Version: $VERSION"

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

case $CMAKE_ARCH in
    x86_64)
        BSD_SHORT_ARCH=amd64
        BSD_ARCH=amd64
    ;;

    i386)
        BSD_SHORT_ARCH=i386
        BSD_ARCH=i386
    ;;

    aarch64)
        BSD_SHORT_ARCH=aarch64
        BSD_ARCH=arm64-aarch64
    ;;

    riscv64)
        BSD_SHORT_ARCH=riscv64
        BSD_ARCH=riscv-riscv64
    ;;
esac

IMG_BASE_URL="https://download.freebsd.org/releases/VM-IMAGES/${VERSION}-RELEASE/${BSD_SHORT_ARCH}/Latest"
IMG="FreeBSD-${VERSION}-RELEASE-${BSD_ARCH}.qcow2"

# curl $IMG_BASE_URL/${IMG}.xz | xz --decompress > ${IMG}

mkdir -p $SYSROOT_PATH/usr/lib
mkdir -p $SYSROOT_PATH/staging

guestfish -a $IMG << EOF
run
mount-vfs ro,ufstype=ufs2 ufs /dev/sda4 /
copy-out /lib $SYSROOT_PATH
copy-out /usr/include $SYSROOT_PATH/usr
copy-out /usr/lib $SYSROOT_PATH/staging
EOF

pushd $SYSROOT_PATH/staging/lib
find -name \*crt\*  -exec cp {} $SYSROOT_PATH/usr/lib \;
find -name libgcc\* -exec cp {} $SYSROOT_PATH/usr/lib \;
cp libc.so libc_nonshared.a \
   libc++.so libcxxrt.so \
   libpthread.so libthr.so \
   libdl.so libdl.so.1 \
   libregex.so libregex.so.1 \
   libssl.so libssl.so.30 \
   librt.so libm.so libcrypto.so libz.so \
   libcompiler_rt.a \
   $SYSROOT_PATH/usr/lib
popd
rm -rf $SYSROOT_PATH/staging

sed -e "s|CMAKE_ARCH_VAR|$CMAKE_ARCH|" \
    -e "s|TARGET_TRIPLE|$TARGET|"      \
    -e "s|--rtlib=compiler-rt||"       \
    -e "s|--unwindlib=libunwind||"     \
    -e "s|-lc++abi||"                  \
    -e "s|Linux|FreeBSD|" $SCRIPT_DIR/toolchain.cmake.final.in > $SYSROOT_PATH/toolchain.cmake

sed -e "s|TARGET_TRIPLE|$TARGET|" \
    -e "s|--rtlib=compiler-rt||"       \
    -e "s|--unwindlib=libunwind||"     \
    -e "s|-lc++abi||" $SCRIPT_DIR/bashenv.in > $SYSROOT_PATH/bashenv
install --mode=0755 $SCRIPT_DIR/activate.sh $SYSROOT_PATH/activate.sh

pushd $SYSROOT_PATH/..
tar caf $SYSROOT_PATH.tar.xz $(basename $SYSROOT_PATH)
popd

rm $IMG
rm -rf $SYSROOT_PATH
