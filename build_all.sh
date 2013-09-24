#!/bin/bash

################################################################################
# Copyright :   (C) 2013
# Author    :   Andrei Costin (andrei@andreicostin.com) (andrei.costin@eurecom.fr)
# Date      :   20130907
# Desc      :   This is custom script to build PostgreSQL plugin/shared-module.
#               We have to do this 'hack' because tested sdhash/libsdbf 3.3 is 
#               not being built and distributed as a proper shared library with 
#               includes and all the stuff
# Usage     :   ./build_sdhash_psql.sh
# License   :   GPLv3
################################################################################

read -e -p "Enter work and build dir: " -i "$PWD/psql_fuzzy" DEST_DIR
echo $DEST_DIR
mkdir -p $DEST_DIR

PSQL_DIR="postgresql-9.2.4"
WGET_PSQL="ftp://ftp.postgresql.org/pub/source/v9.2.4/$PSQL_DIR.tar.gz"

SDHASH_DIR="sdhash-3.3"
WGET_SDHASH="http://roussev.net/sdhash/releases/packages/$SDHASH_DIR.tar.gz"

SSDEEP_PSQL_DIR="ssdeep_psql"
GIT_SSDEEP_PSQL="https://github.com/bernerdschaefer/$SSDEEP_PSQL_DIR.git"

SDHASH_PSQL_DIR="sdhash_psql"
GIT_SDHASH_PSQL="https://github.com/eurecom-s3/$SDHASH_PSQL_DIR.git"

################################################################################

cd $DEST_DIR
wget $WGET_SDHASH
tar -xzvf $SDHASH_DIR.tar.gz
cd $SDHASH_DIR

# Patch for 32bit systems
PLATFORM=`getconf LONG_BIT`

if [ $PLATFORM -eq 32 ];
then
    grep "D_M_IX86" Makefile
    if [ $? -ne 0 ];
    then
        cp Makefile Makefile.original
        sed 's@CFLAGS = @CFLAGS = -D_M_IX86 @g' -i Makefile
    fi

    grep "//local_cpuid" ./sdbf/sdbf_conf.cc
    if [ $? -ne 0 ];
    then
        cp ./sdbf/sdbf_conf.cc ./sdbf/sdbf_conf.cc.original
        sed 's@local_cpuid@//local_cpuid@g' -i ./sdbf/sdbf_conf.cc
    fi
fi

# Patch for 64bit platforms (works well on 32bit platforms as well) to properly 
# build of static version of sdhash-supplied boost library on
FILE_SDHASH_MAKEFILE="Makefile"
if [ `grep "link=static" $FILE_SDHASH_MAKEFILE | grep "fPIC" | wc -l` -eq 0 ];
then
    sed -i 's@b2 link=static@b2 link=static cxxflags=-fPIC cflags=-fPIC@g' $FILE_SDHASH_MAKEFILE
fi

make
if [ $? -ne 0 ];
then
    echo "Error: build failed for $SDHASH_DIR"
    exit 1
fi

################################################################################

cd $DEST_DIR
wget $WGET_PSQL
tar -xzvf $PSQL_DIR.tar.gz
cd $PSQL_DIR

./configure
if [ $? -ne 0 ];
then
    echo "Error: configure failed for $PSQL_DIR"
    exit 1
fi

# Patch PostgreSQL to be able to link agains C++ object-files/libraries
# http://postgresql.1045698.n5.nabble.com/Mostly-Harmless-Welcoming-our-C-friends-td2011266.html
# http://www.linuxquestions.org/questions/programming-9/how-to-make-g-behave-like-gcc-in-this-case-795524/
# HACK: though this is a dirty hack for now, let it work until the proper patch is in the PostgreSQL main branch

FILE_BUILTINS_H="./src/include/utils/builtins.h"
if [ `grep '__cplusplus' $FILE_BUILTINS_H | wc -l` -ne 2 ];
then
    sed -i 's@#define BUILTINS_H@#define BUILTINS_H\n\n#ifdef __cplusplus\nextern "C" {\n#endif\n@g' $FILE_BUILTINS_H
    sed -i 's@#endif   /\* BUILTINS_H \*/@\n#ifdef __cplusplus\n}; /* extern "C" */\n#endif\n\n#endif   /* BUILTINS_H */@g' $FILE_BUILTINS_H
fi

FILE_PALLOC_H="./src/include/utils/palloc.h"
if [ `grep '__cplusplus' $FILE_PALLOC_H | wc -l` -ne 2 ];
then
    sed -i 's@#define PALLOC_H@#define PALLOC_H\n\n#ifdef __cplusplus\nextern "C" {\n#endif\n@g' $FILE_PALLOC_H
    sed -i 's@#endif   /\* PALLOC_H \*/@\n#ifdef __cplusplus\n}; /* extern "C" */\n#endif\n\n#endif   /* PALLOC_H */@g' $FILE_PALLOC_H
fi

FILE_FMGR_H="./src/include/fmgr.h"
if [ `grep '__cplusplus' $FILE_FMGR_H | wc -l` -ne 2 ];
then
    sed -i 's@#define FMGR_H@#define FMGR_H\n\n#ifdef __cplusplus\nextern "C" {\n#endif\n@g' $FILE_FMGR_H
    sed -i 's@#endif   /\* FMGR_H \*/@\n#ifdef __cplusplus\n}; /* extern "C" */\n#endif\n\n#endif   /* FMGR_H */@g' $FILE_FMGR_H
fi

make
if [ $? -ne 0 ];
then
    echo "Error: build failed for $PSQL_DIR"
    exit 1
fi

# This tests the PostreSQL core
make check
# TODO: add error handling in case tests failed

################################################################################

cd $DEST_DIR/$PSQL_DIR/contrib
git clone $GIT_SSDEEP_PSQL
cd $SSDEEP_PSQL_DIR

make
if [ $? -ne 0 ];
then
    echo "Error: build failed for $SSDEEP_PSQL_DIR"
    exit 1
fi

cd $DEST_DIR/$PSQL_DIR/contrib
git clone $GIT_SDHASH_PSQL
cd $SDHASH_PSQL_DIR
ln -s $DEST_DIR/$SDHASH_DIR sdhash-dist
./build_sdhash_psql.sh


cd $DEST_DIR/$PSQL_DIR/contrib

# Patch $DEST_DIR/$PSQL_DIR/contrib/Makefile to contain fuzzy-hashing plugins:
# ssdeep_psql
# sdhash_psql
# HACK: though this is a dirty hack for now

FILE_CONTRIB_MAKEFILE="Makefile"
if [ `egrep -e "(ssdeep_psql)|(sdhash_psql)" $FILE_CONTRIB_MAKEFILE | wc -l` -ne 2 ];
then
    sed -i 's@SUBDIRS = \\@SUBDIRS = \\\n\t\tssdeep_psql\t\\\n\t\tsdhash_psql\t\\@g' $FILE_CONTRIB_MAKEFILE
fi

make
if [ $? -ne 0 ];
then
    echo "Error: build failed for $PSQL_DIR/contrib"
    exit 1
fi

# This builds the plugins from './contrib' of PostreSQL
cd $DEST_DIR/$PSQL_DIR
make world

# This tests the plugins from './contrib' of PostreSQL
cd $DEST_DIR/$PSQL_DIR
make check-world
# TODO: add error handling in case tests failed

################################################################################

cd $DEST_DIR/$PSQL_DIR

# This installs the PostreSQL
sudo make install

# This installs the plugins from './contrib' of PostreSQL
sudo make install-world

