////////////////////////////////////////////////////////////////////////////////
// Copyright:   (C) 2013
// Author   :   Andrei Costin (andrei@andreicostin.com) (andrei.costin@eurecom.fr)
// Date     :   20130907
// Desc     :   Implements interfacing from PostgreSQL function into the 
//              sdhash C++-based functions
// Credits  :   Based on https://github.com/bernerdschaefer/ssdeep_psql
// License  :   GPLv3
////////////////////////////////////////////////////////////////////////////////

#include <stdlib.h> 
#include "postgres.h"
#include "fmgr.h"
#include "./utils/builtins.h"
// These includes are adapted from "sdhash-src/sdhash.cc" file. Keep in sync with future versions of "sdhash-src/sdhash.cc"
#include "sdbf/sdbf_class.h"
#include "sdbf/sdbf_defines.h"
#include "sdbf/sdbf_set.h"

#define ERROR_INT32     -1
#define ERROR_TEXT      ""

#ifdef __cplusplus
extern "C" {
#endif 


PG_MODULE_MAGIC;

PG_FUNCTION_INFO_V1(pg_sdhash_hash);
//Datum pg_sdhash_hash(PG_FUNCTION_ARGS);

Datum pg_sdhash_hash(PG_FUNCTION_ARGS) {
    try
    {
        text *arg = PG_GETARG_TEXT_P(0);
        int arg_size = VARSIZE(arg) - VARHDRSZ;

        text *pg_hash;
        int hash_length;

        // 0 means we don't want dd_block mode, rather we want stream mode
        sdbf *hash_sdbf = new sdbf((char *) "sdbf_from_stream", (char *) VARDATA(arg), (uint32_t) 0, (uint64_t) arg_size, (index_info *)NULL);
        std::string hash_str = hash_sdbf->to_string();

        hash_length = hash_str.length();
        pg_hash = (text *) palloc(hash_length);

        SET_VARSIZE(pg_hash, hash_length+VARHDRSZ);
        memcpy(VARDATA(pg_hash), hash_str.c_str(), hash_length);

        delete hash_sdbf;

        PG_RETURN_TEXT_P(pg_hash);
    }
    catch(exception& e)
    {
        PG_RETURN_TEXT_P(cstring_to_text(ERROR_TEXT));
    }
    catch(int e)
    {
        PG_RETURN_TEXT_P(cstring_to_text(ERROR_TEXT));
    }
}
// 
// CREATE OR REPLACE FUNCTION sdhash_hash(TEXT) RETURNS TEXT AS 'sdhash_psql.so', 'pg_sdhash_hash' LANGUAGE 'c';
//

PG_FUNCTION_INFO_V1(pg_sdhash_compare);
//Datum pg_sdhash_compare(PG_FUNCTION_ARGS);

Datum pg_sdhash_compare(PG_FUNCTION_ARGS) {
    try
    {
        text *arg1 = PG_GETARG_TEXT_P(0);
        text *arg2 = PG_GETARG_TEXT_P(1);
        int arg_size1 = VARSIZE(arg1) - VARHDRSZ;
        int arg_size2 = VARSIZE(arg2) - VARHDRSZ;
        int32 score;

        // 0 means we don't want dd_block mode, rather we want stream mode
        sdbf *hash_sdbf1 = new sdbf((char *) "sdbf_from_stream", (char *) VARDATA(arg1), (uint32_t) 0, (uint64_t) arg_size1, (index_info *)NULL);
        sdbf *hash_sdbf2 = new sdbf((char *) "sdbf_from_stream", (char *) VARDATA(arg2), (uint32_t) 0, (uint64_t) arg_size2, (index_info *)NULL);

        // Keep 0 in sync with sdhash.cc: sdbf_sys.sample_size
        score = (int32) hash_sdbf1->compare(hash_sdbf2, 0);

        delete hash_sdbf1;
        delete hash_sdbf2;

        PG_RETURN_INT32(score);
    }
    catch(exception& e)
    {
        PG_RETURN_INT32(ERROR_INT32);
    }
    catch(int e)
    {
        PG_RETURN_INT32(e);
    }
}
// 
// CREATE OR REPLACE FUNCTION sdhash_compare(TEXT, TEXT) RETURNS INTEGER AS 'sdhash_psql.so', 'pg_sdhash_compare' LANGUAGE 'c';
//

PG_FUNCTION_INFO_V1(pg_sdhash_hash_compare);
//Datum pg_sdhash_hash_compare(PG_FUNCTION_ARGS);

Datum pg_sdhash_hash_compare(PG_FUNCTION_ARGS) {
    char *str1 = NULL;
    char *str2 = NULL;
    sdbf *_sdbf1 = NULL;
    sdbf *_sdbf2 = NULL;

    try
    {
        text *arg1 = PG_GETARG_TEXT_P(0);
        text *arg2 = PG_GETARG_TEXT_P(1);
        int arg_size1 = VARSIZE(arg1) - VARHDRSZ;
        int arg_size2 = VARSIZE(arg2) - VARHDRSZ;
        int32 score;

        str1 = (char *) malloc(arg_size1 + 1);
        memcpy(str1, (char *) VARDATA(arg1), arg_size1);
        str1[arg_size1] = '\0';

        str2 = (char *) malloc(arg_size2 + 1);
        memcpy(str2, (char *) VARDATA(arg2), arg_size2);
        str2[arg_size2] = '\0';
        
        _sdbf1 = new sdbf(str1);
        _sdbf2 = new sdbf(str2);

        score = (int32) _sdbf1->compare(_sdbf2, 0);

        // Cleanup the memory
        if (str1)
        {
            free(str1);
            str1 = NULL;
        }

        if (str2)
        {
            free(str2);
            str2 = NULL;
        }
        
        if (_sdbf1)
        {
            delete _sdbf1;
            _sdbf1 = NULL;
        }

        if (_sdbf2)
        {
            delete _sdbf2;
            _sdbf2 = NULL;
        }

        PG_RETURN_INT32(score);
    }
    catch(exception& e)
    {
        // Cleanup the memory
        if (str1)
        {
            free(str1);
            str1 = NULL;
        }

        if (str2)
        {
            free(str2);
            str2 = NULL;
        }

        if (_sdbf1)
        {
            delete _sdbf1;
            _sdbf1 = NULL;
        }

        if (_sdbf2)
        {
            delete _sdbf2;
            _sdbf2 = NULL;
        }

        PG_RETURN_INT32(ERROR_INT32);
    }
    catch(int e)
    {
        // Cleanup the memory
        if (str1)
        {
            free(str1);
            str1 = NULL;
        }

        if (str2)
        {
            free(str2);
            str2 = NULL;
        }

        if (_sdbf1)
        {
            delete _sdbf1;
            _sdbf1 = NULL;
        }

        if (_sdbf2)
        {
            delete _sdbf2;
            _sdbf2 = NULL;
        }

        PG_RETURN_INT32(e);
    }
}
// 
// CREATE OR REPLACE FUNCTION sdhash_hash_compare(TEXT, TEXT) RETURNS INTEGER AS 'sdhash_psql.so', 'pg_sdhash_hash_compare' LANGUAGE 'c';
//

#ifdef __cplusplus
}; /* extern "C" */
#endif 

