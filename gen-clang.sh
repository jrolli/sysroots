
set -euo pipefail

TOOLCHAIN=$1
echo "Toolchain: $TOOLCHAIN"
echo "LLVM src dir:  $LLVM_SRC_DIR"

curl https://www.zlib.net/zlib-1.3.1.tar.xz | tar xJ
cmake -B build-zlib \
      -S zlib-1.3.1 \
      -G Ninja \
      --toolchain=`pwd`/$TOOLCHAIN/toolchain.cmake \
      -DBUILD_SHARED_LIBS=OFF \
      -DCMAKE_BUILD_TYPE=MinSizeRel \
      -DCMAKE_INSTALL_PREFIX=`pwd`/zlib-install
cmake --build build-zlib
cmake --install build-zlib

cmake -B build-clang \
      -S $LLVM_SRC_DIR/llvm \
      -G Ninja \
      --toolchain=`pwd`/$TOOLCHAIN/toolchain.cmake \
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
cmake --build build-clang
DESTDIR=`pwd`/llvm-$TOOLCHAIN cmake --build build-clang --target install
mv llvm-$TOOLCHAIN/usr/* llvm-$TOOLCHAIN
rmdir llvm-$TOOLCHAIN/usr
find llvm-$TOOLCHAIN -type f -exec llvm-strip --strip-all {} \; 2>/dev/null
tar cJvf llvm-$TOOLCHAIN.tar.xz llvm-$TOOLCHAIN
