# sysroots

This is a project to streamline the production of relatively minimal system
roots (sysroots) for cross-compiling with the llvm toolchain.

You will need to have source code downloaded and unpacked for musl, llvm, and
the linux kernel.  Additionally, you'll need to have a version of clang
installed that supports your desired target architecture.

_Note:_ While the sysroots will have GPL code in them (the Linux headers), the
 resulting binaries should only include LLVM (Apache 2.0 with attribution
 requirements likely exempted), musl (MIT licensed) object code, or GPL code
 that you either explicitly included (via `--static`) or is excepted via LGPL
 or GCC's and glibc's exception clauses.

Example usage:
```bash
./generate.sh aarch64-linux-musl
# File `aarch64-linux-musl.tar.xz` outputted to working directory

tar xf aarch64-linux-musl.tar.xz

cmake -Bbuild -Spath/to/your/project --toolchain=aarch64-linux-musl
cmake --build build
```

## FreeBSD VMs
```bash
qemu-system-x86_64 \
    -nic user,smb=/home/jrollinson/,smbserver=10.0.2.5 \
    -device virtio-blk-pci,drive=hd0 \
    -drive if=none,id=hd0,format=qcow2,file=FreeBSD-14.1-RELEASE-amd64.qcow2 \
    -snapshot
```

## Adding ucontext support

It can be temperamental and there are some potential upstream libucontext
issues, but basic support for libucontext can be added via the following code.

```bash
source $SYSROOT_PATH/bashenv

pushd $LIBUCONTEXT_SRC_DIR
export CFLAGS="$CFLAGS -ffile-prefix-map=$(pwd)=libucontext"
export LDFLAGS="$CFLAGS -B$SYSROOT_PATH/lib $LDFLAGS"

make ARCH=$CMAKE_ARCH clean
make ARCH=$CMAKE_ARCH
make ARCH=$CMAKE_ARCH DESTDIR=$SYSROOT_PATH install
find $SYSROOT_PATH -name libucontext\*.so\* -delete
popd
```

## Building Clang

```bash
curl https://www.zlib.net/zlib-1.3.1.tar.xz | tar xJ
cmake -B build-zlib \
    -S zlib-1.3.1 \
    -G Ninja \
    --toolchain=`pwd`/x86_64-linux-glibc2.28/toolchain.cmake \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_BUILD_TYPE=MinSizeRel \
    -DCMAKE_INSTALL_PREFIX=`pwd`/zlib-install
cmake --build build-zlib
cmake --install build-zlib
cmake -B build \
      -S `pwd`/llvm \
      -G Ninja \
      --toolchain=`pwd`/x86_64-linux-glibc2.28/toolchain.cmake \
      -DCMAKE_BUILD_TYPE=MinSizeRel \
      -DCMAKE_INSTALL_PREFIX="/" \
      -DHAVE_CXX_ATOMICS64_WITHOUT_LIB=ON \
      -DHAVE_CXX_ATOMICS_WITHOUT_LIB=ON \
      -DLLVM_APPEND_VC_REV=OFF \
      -DLLVM_BUILD_LLVM_DYLIB=ON \
      -DLLVM_ENABLE_FFI=OFF \
      -DLLVM_ENABLE_LIBCXX=ON \
      -DLLVM_ENABLE_LIBEDIT=OFF \
      -DLLVM_ENABLE_PROJECTS="clang;lld;clang-tools-extra" \
      -DLLVM_ENABLE_UNWIND_TABLES=OFF \
      -DLLVM_ENABLE_ZLIB=FORCE_ON \
      -DLLVM_FORCE_VC_REPOSITORY=OFF \
      -DLLVM_FORCE_VC_REVISION=manylinux_2_28 \
      -DLLVM_INCLUDE_BENCHMARKS=OFF \
      -DLLVM_INCLUDE_EXAMPLES=OFF \
      -DLLVM_INSTALL_TOOLCHAIN_ONLY=ON \
      -DLLVM_LINK_LLVM_DYLIB=ON \
      -DLLVM_TARGETS_TO_BUILD="AArch64;ARM;BPF;LoongArch;Mips;PowerPC;RISCV;Sparc;WebAssembly;X86" \
      -DZLIB_INCLUDE_DIR=`pwd`/zlib-install/include \
      -DZLIB_LIBRARY=`pwd`/zlib-install/lib/libz.a
```

## Design

This is a work in progress, but here are some of the current design decisions:

1. Tarballs vs packages - For controlled environments where libraries can be
directly specified, a global sysroot can be easily reused across several
projects.  Unfortunately, some projects/dependencies assume there is a single
sysroot that also contains pkgconfig information.  This project tries to
support the automated cross-compiling of open-source projects and therefore
assumes you will need to modify the sysroot as part of your build process
(ie, building and installing dependencies).

2. LLVM tooling vs GCC - LLVM seems to have a more active community for
third-party extensions (see 
[Macaroni](https://blog.trailofbits.com/2023/09/11/holy-macroni-a-recipe-for-progressive-language-enhancement/))
with which this project hopes to nest.  Additionally, this project makes it
cheaper and quicker to add additional sysroots (300MiB base + ~3 MiB per
target) than GCC's full compiler-toolchain per target (150+ MiB per target).
Finally, the LLVM tooling more easily supports adding non-Linux targets
(macOS, Windows, BSDs, etc.) than GCC's tooling which is also a long-term
goal for the project.
