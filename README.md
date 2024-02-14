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
