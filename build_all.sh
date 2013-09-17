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
GIT_SDHASH_PSQL="https://github.com/zveriu/$SDHASH_PSQL_DIR.git"

################################################################################

cd $DEST_DIR
wget $WGET_SDHASH
tar -xzvf $SDHASH_DIR.tar.gz
cd $SDHASH_DIR

# TODO: auto-patch for 32bit systems

#make
echo TODO
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

#./configure
echo TODO
if [ $? -ne 0 ];
then
    echo "Error: configure failed for $PSQL_DIR"
    exit 1
fi

# TODO: auto-patch src/include/utils/palloc.h and src/include/fmgr.h with wrapping
# http://postgresql.1045698.n5.nabble.com/Mostly-Harmless-Welcoming-our-C-friends-td2011266.html
# http://www.linuxquestions.org/questions/programming-9/how-to-make-g-behave-like-gcc-in-this-case-795524/
#
#   #ifdef __cplusplus
#   extern "C" {
#   #endif 
#
#   #ifdef __cplusplus
#   }; /* extern "C" */
#   #endif 

#make
echo TODO
if [ $? -ne 0 ];
then
    echo "Error: build failed for $PSQL_DIR"
    exit 1
fi

#make check
echo TODO

################################################################################

cd $DEST_DIR/$PSQL_DIR/contrib
git clone $GIT_SSDEEP_PSQL
cd $SSDEEP_PSQL_DIR

#make
echo TODO
if [ $? -ne 0 ];
then
    echo "Error: build failed for $SSDEEP_PSQL_DIR"
    exit 1
fi

cd $DEST_DIR/$PSQL_DIR/contrib
git clone $GIT_SDHASH_PSQL
cd $SDHASH_PSQL_DIR
ln -s $DEST_DIR/$SDHASH_DIR sdhash-dist
#./build_sdhash_psql.sh
echo TODO

# TODO: auto-patch $DEST_DIR/$PSQL_DIR/contrib/Makefile to contain:
#SUBDIRS = \
#                ssdeep_psql     \
#                sdhash_psql     \
cd $DEST_DIR/$PSQL_DIR/contrib
#make
echo TODO
if [ $? -ne 0 ];
then
    echo "Error: build failed for $PSQL_DIR/contrib"
    exit 1
fi

# Test the psql core
cd $DEST_DIR/$PSQL_DIR
#make world
echo TODO

# Test the contrib plugins
cd $DEST_DIR/$PSQL_DIR
#make check-world
echo TODO

################################################################################

#sudo make install
echo TODO
#sudo make install-world
echo TODO

