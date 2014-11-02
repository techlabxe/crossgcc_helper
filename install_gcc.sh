#!/bin/bash
 
# version
gmp=gmp-4.3.2
mpfr=mpfr-2.4.2
mpc=mpc-0.8.1
binutils=binutils-2.21.1
# gcc=gcc-4.6.3
gcc=gcc-4.5.3
eglibc=eglibc-2.13
linux=linux-3.0.45
 
# constant variables
tarballtop=$(pwd)
worktop=$(pwd)
tools=$worktop/arm-built-from-src
target=arm-none-linux-gnueabi
sysroot=$tools/$target/libc
linux_arch=arm
 
 
# special parameters for cygwin
gcc_cygwin_params=
gcc_step3_cygwin_params=
case `uname` in
  CYGWIN*) 
    gcc_cygwin_params="MAKEINFO=missing"
    gcc_step3_cygwin_params="--disable-libstdcxx-pch"
    ;;
  *)
    ;;
esac

#
# helper functions
#
msg () {
    echo ";"
    echo ";"
    echo ";;;;;   $1   ;;;;;"
    echo ";"
    echo ";"
}
 
usage () {
 
cat <<eof>&2
usage: install_gcc.sh [-t tarballtop] [-w worktop] [-T tools] [targets...]
 
Valid targets are:
   binutils    Build and install binutils
   gcc1        Build and install the first gcc
   linuxhdr    Install Linux kernel headers
   eglibchdr   Install EGLIBC headers
   gcc2        Build and install the second gcc
   eglibc      Build and install eglibc
   gcc3        Build and install the third gcc
   all         Do all of above in above order
 
   If no target is given, "install_gcc all" shall be run.
eof
}
 
optcheck () {
    if [ -z $2 ] || [ $(echo $2 | cut -c 1) != "/" ]; then
        echo "error: specify absolute pass for $1 option"
        exit 1
    fi
}
 
unpack () {
    # search *.tar.gz, *.tar.bz2, *.tar.xz, *.tgz, *.tbz2 *.tar
    # in this order.
    # If found, the tarball shall be uncompressed.
 
    for suffix in tar.gz tar.bz2 tar.xz tgz tbz2 tar; do
        tarball=$tarballtop/$1.$suffix
        if [ -f $tarball ]; then
            case $suffix in
                tar.gz)  taropt=-zxf ;;
                tar.bz2) taropt=-jxf ;;
                tar.xz)  taropt=-Jxf ;;
                tgz)     taropt=-zxf ;;
                tbz2)    taropt=-jxf ;;
                tar)     taropt=-xf  ;;
                *)       echo "error: something wrong. fix me." >&2 ; exit 1 ;;
            esac
            echo "uncompressing $tarball ..."
            tar $taropt $tarball
            return
        fi
    done
 
    echo "error: tarball not found. Abort." >&2
    exit 1
}
 
gcc_prerequisites () {
    # $1: relative or absolute path to gcc source directory
 
    # sanity check
    if [ -z $1 ]; then
        echo "error: gcc_prerequisites was called without args" >&2
        exit 1
    fi
    gccdir=$1
    if [ ! -d $gccdir ]; then
        echo "error: directory \'$gccdir\' not found"
        exit 1
    fi
 
    #    cd $gccdir
    #    ./contrib/download_prerequisites
    #   Instead of doing above, do following:
    unpack $gmp
    unpack $mpfr
    unpack $mpc
 
    mv $gmp $mpfr $mpc $gccdir/
    ln -s $gmp $gccdir/gmp
    ln -s $mpfr $gccdir/mpfr
    ln -s $mpc $gccdir/mpc
}
 
install_binutils () {
    srcdir=$binutils
    objdir=obj-binutils
 
    cd $worktop
    rm -rf $srcdir $objdir
    unpack $srcdir
    mkdir -p $objdir
    cd $objdir
 
    $worktop/$srcdir/configure \
        --target=$target \
        --prefix=$tools \
        --with-sysroot=$sysroot
    make
    make install
 
    cd $worktop
    rm -rf $srcdir $objdir
}
 
install_gcc1 () {
    srcdir=$gcc
    objdir=obj-gcc1
 
    cd $worktop
    rm -rf $srcdir $objdir
    unpack $srcdir
    gcc_prerequisites $srcdir
    mkdir -p $objdir
    cd $objdir
 
    $worktop/$srcdir/configure \
        --target=$target \
        --prefix=$tools \
        --without-headers --with-newlib \
        --disable-shared --disable-threads --disable-libssp \
        --disable-libgomp --disable-libmudflap \
        --disable-libquadmath \
        --enable-languages=c \
        $gcc_cygwin_params

    PATH=$tools/bin:$PATH make
    PATH=$tools/bin:$PATH make install
 
    cd $worktop
    rm -rf $srcdir $objdir
}
 
install_linuxhdr () {
    srcdir=$linux
 
    cd $worktop
    rm -rf $srcdir
    unpack $srcdir
    cd $srcdir
    make headers_install \
        ARCH=$linux_arch CROSS_COMPILE=$target- \
        INSTALL_HDR_PATH=$sysroot/usr
 
    cd $worktop
    rm -rf $srcdir
}
 
install_eglibchdr () {
    srcdir=$eglibc
    objdir=obj-eglibc-headers
 
    cd $worktop
    rm -rf $srcdir $objdir
    unpack $srcdir
    mv $srcdir/ports $srcdir/libc
    mkdir -p $objdir
    cd $objdir
 
    BUILD_CC=gcc \
    CC=$tools/bin/$target-gcc \
    CXX=$tools/bin/$target-g++ \
    AR=$tools/bin/$target-ar \
    RANLIB=$tools/bin/$target-ranlib \
    $worktop/$srcdir/libc/configure \
        --prefix=/usr \
        --with-headers=$sysroot/usr/include \
        --host=$target \
        --disable-profile --without-gd --without-cvs --enable-add-ons
 
    make install-headers install_root=$sysroot \
        install-bootstrap-headers=yes
 
    make csu/subdir_lib
 
    mkdir -p $sysroot/usr/lib
    cp csu/crt1.o csu/crti.o csu/crtn.o $sysroot/usr/lib
 
    $tools/bin/$target-gcc -nostdlib -nostartfiles -shared -x c /dev/null \
        -o $sysroot/usr/lib/libc.so
 
    cd $worktop
    rm -rf $srcdir $objdir
}
 
install_gcc2 () {
    srcdir=$gcc
    objdir=obj-gcc2
 
    cd $worktop
    rm -rf $srcdir $objdir
    unpack $srcdir
    gcc_prerequisites $srcdir
    mkdir -p $objdir
    cd $objdir
 
    $worktop/$srcdir/configure \
        --target=$target \
        --prefix=$tools \
        --with-sysroot=$sysroot \
        --disable-libssp --disable-libgomp --disable-libmudflap \
        --disable-libquadmath \
        --enable-languages=c \
        $gcc_cygwin_params

    PATH=$tools/bin:$PATH make
    PATH=$tools/bin:$PATH make install
 
    cd $worktop
    rm -rf $srcdir $objdir
}
 
install_eglibc () {
    srcdir=$eglibc
    objdir=obj-eglibc
 
    cd $worktop
    rm -rf $srcdir $objdir
    unpack $srcdir
    mv $srcdir/ports $srcdir/libc

    pushd .
    cd $srcdir
    patch -p1 -u < ../cygwin-make-patch_eglibc-2.13.patch
    popd

    mkdir -p $objdir
    cd $objdir
 
    BUILD_CC=gcc \
    CC=$tools/bin/$target-gcc \
    CXX=$tools/bin/$target-g++ \
    AR=$tools/bin/$target-ar \
    RANLIB=$tools/bin/$target-ranlib \
    $worktop/$srcdir/libc/configure \
        --prefix=/usr \
        --with-headers=$sysroot/usr/include \
        --host=$target \
        --disable-profile --without-gd --without-cvs --enable-add-ons
    PATH=$tools/bin:$PATH make
    PATH=$tools/bin:$PATH make install install_root=$sysroot
 
    cd $worktop
    rm -rf $srcdir $objdir
}
 
install_gcc3 () {
    srcdir=$gcc
    objdir=obj-gcc3
 
    cd $worktop
    rm -rf $srcdir $objdir
    unpack $srcdir
    gcc_prerequisites $srcdir
    mkdir -p $objdir
    cd $objdir
 
    $worktop/$srcdir/configure \
        --target=$target \
        --prefix=$tools \
        --with-sysroot=$sysroot \
        --enable-__cxa_atexit \
        --disable-libssp --disable-libgomp --disable-libmudflap \
        --enable-languages=c,c++ \
        $gcc_step3_cygwin_params \
        $gcc_cygwin_params
    make 
    make install
 
    cd $worktop
    rm -rf $srcdir $objdir
}
 
# stop immediately if an error occurres
set -e
 
# process options
while [ $# -gt 0 ] ; do
    case "$1" in
        -t) optcheck $1 $2; shift; tarballtop=$1 ;;
        -w) optcheck $1 $2; shift; worktop=$1 ;;
        -T) optcheck $1 $2; shift; tools=$1; sysroot=$tools/$target/libc ;;
        -*) (echo error: $1: unknown option ; echo ) >&2 ; usage ; exit 1 ;;
        *) break;;
    esac
    shift
done
 
if [ $# -eq 0 ] ; then
    set all
fi
 
# process targets
while [ $# -gt 0 ] ; do
    case "$1" in
        binutils)  msg binutils ; install_binutils ;;
        gcc1)      msg gcc1 ; install_gcc1 ;;
        linuxhdr)  msg linuxhdr ; install_linuxhdr ;;
        eglibchdr) msg eglibchdr ; install_eglibchdr ;;
        gcc2)      msg gcc2 ; install_gcc2 ;;
        eglibc)    msg eglibc ; install_eglibc ;;
        gcc3)      msg gcc3 ; install_gcc3 ;;
        all)       set binutils gcc1 linuxhdr eglibchdr gcc2 eglibc gcc3 ;
     continue  ;;
        *)         (echo error: $1: unknown target ; echo ) >&2 ; usage ; exit 1;;
    esac
    shift
done


# このオリジナルのスクリプトは以下のサイトで公開されていた物です。
# http://masahir0y.blogspot.jp/2012/10/arm.html
# この情報のおかげでcross compiler gcc の作成が出来たので感謝です。
# 
# Version History
#   0.01 initial (original)
#   0.02 build support on cygwin(x64) for windows7.
