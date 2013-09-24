#!/bin/bash

################################################################################
# Copyright :   (C) 2013
# Author    :   Andrei Costin (andrei@andreicostin.com) (andrei.costin@eurecom.fr)
# Date      :   20130907
# Desc      :   This is custom script to build PostgreSQL plugin/shared-module.
#               We have to do this 'hack' because sdhash/libsdbf is not being
#               built and distributed as a proper shared library with includes.
# Usage     :   ./build_sdhash_psql.sh
# License   :   GPLv3
################################################################################

rm -f *.o *.so

# Build the compiled object file
stage_build=`make 2>/dev/null | sed 's@gcc@g++@g' | sed 's@sdhash_psql.o@sdhash_psql.o ./sdhash-dist/libsdbf.a @g' | sed 's@-I. @-I./sdhash-dist -I. @g'`
echo $stage_build | grep "Nothing to be done"
if [ $? -ne 0 ];
then
    echo $stage_build
    $stage_build
fi
#nm -a sdhash_psql.o | grep sdbf | grep " U "

# Link into shared library and link into it the static libsdbf.a
stage_link=`make 2>/dev/null | sed 's@gcc@g++@g' | sed 's@sdhash_psql.o@sdhash_psql.o ./sdhash-dist/libsdbf.a -fopenmp -L./sdhash-dist -L./sdhash-dist/external/stage/lib -lboost_system -lboost_filesystem -lboost_program_options -lc -lm -lcrypto -lboost_thread -lpthread ./sdhash-dist/external/stage/lib/libboost_thread.a ./sdhash-dist/external/stage/lib/libboost_filesystem.a ./sdhash-dist/external/stage/lib/libboost_system.a @g'`
#nm -a sdhash_psql.so | grep sdbf | grep " U "
echo $stage_link | grep "Nothing to be done"
if [ $? -ne 0 ];
then
    echo $stage_link
    $stage_link
fi

# Verify build and linkage is ok
nm -a sdhash_psql.so | grep sdbf | grep " U "
if [ $? -eq 0 ];
then
    echo "Error: UNDEFINED sdhash symbols still found in the shared library .so"
    exit 1
fi

nm -a sdhash_psql.so | grep boost | grep " U "
