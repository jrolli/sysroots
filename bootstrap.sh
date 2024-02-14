#!/bin/bash

yum install glibc-devel -y

cp -r /usr/include /sysroot/

if uname -p | grep -q 64
then
    LIB=lib64
else
    LIB=lib
fi

install -D -d /sysroot/$LIB
cp --preserve=all /usr/$LIB/*crt*.o      /sysroot/$LIB
cp --preserve=all /usr/$LIB/ld*          /sysroot/$LIB
cp --preserve=all /usr/$LIB/libc.*       /sysroot/$LIB
cp --preserve=all /usr/$LIB/libc-*       /sysroot/$LIB
cp --preserve=all /usr/$LIB/libc_*       /sysroot/$LIB
cp --preserve=all /usr/$LIB/libdl.*      /sysroot/$LIB
cp --preserve=all /usr/$LIB/libdl-*      /sysroot/$LIB
cp --preserve=all /usr/$LIB/libdl_*      /sysroot/$LIB
cp --preserve=all /usr/$LIB/librt.*      /sysroot/$LIB
cp --preserve=all /usr/$LIB/librt-*      /sysroot/$LIB
cp --preserve=all /usr/$LIB/librt_*      /sysroot/$LIB
cp --preserve=all /usr/$LIB/libpthread.* /sysroot/$LIB
cp --preserve=all /usr/$LIB/libpthread-* /sysroot/$LIB
cp --preserve=all /usr/$LIB/libpthread_* /sysroot/$LIB
cp --preserve=all /usr/$LIB/libm.*       /sysroot/$LIB
cp --preserve=all /usr/$LIB/libm-*       /sysroot/$LIB
cp --preserve=all /usr/$LIB/libm_*       /sysroot/$LIB

# Add do-nothing endpoints for old init methods
touch /sysroot/$LIB/crtbegin.o
touch /sysroot/$LIB/crtbeginT.o
touch /sysroot/$LIB/crtend.o

sed -i -E 's|(/usr)?/lib(64)?/||g' /sysroot/lib/libc.so

rm /sysroot/bootstrap.sh
