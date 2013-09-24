////////////////////////////////////////////////////////////////////////////////
// Copyright:   (C) 2013
// Author   :   Andrei Costin (andrei@andreicostin.com) (andrei.costin@eurecom.fr)
// Date     :   20130907
// Desc     :   Implements interfacing from PostgreSQL function into the 
//              sdhash C++-based functions
// Credits  :   Based on https://github.com/bernerdschaefer/ssdeep_psql
// License  :   GPLv3
////////////////////////////////////////////////////////////////////////////////

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
        PG_RETURN_INT32(ERROR_INT32);
    }
}
// 
// CREATE OR REPLACE FUNCTION sdhash_compare(TEXT, TEXT) RETURNS INTEGER AS 'sdhash_psql.so', 'pg_sdhash_compare' LANGUAGE 'c';
//

PG_FUNCTION_INFO_V1(pg_sdhash_hash_compare);
//Datum pg_sdhash_hash_compare(PG_FUNCTION_ARGS);

Datum pg_sdhash_hash_compare(PG_FUNCTION_ARGS) {
    try
    {
        text *arg1 = PG_GETARG_TEXT_P(0);
        text *arg2 = PG_GETARG_TEXT_P(1);
        int arg_size1 = VARSIZE(arg1) - VARHDRSZ;
        int arg_size2 = VARSIZE(arg2) - VARHDRSZ;
        int32 score;
        int pipe1[2];
        int pipe2[2];
        FILE *hash_fp1 = NULL;
        FILE *hash_fp2 = NULL;

        // http://stackoverflow.com/a/5848611
        pipe(pipe1);
        pipe(pipe2);

        hash_fp1 = fdopen(pipe1[0], "r");
        hash_fp2 = fdopen(pipe2[0], "r");

        write(pipe1[1], (char *) VARDATA(arg1), arg_size1);
        write(pipe2[1], (char *) VARDATA(arg2), arg_size2);

        // This sends an EOF onto the FILE*
        // http://stackoverflow.com/a/13521465
        close(pipe1[1]);
        close(pipe2[1]);

        // http://stackoverflow.com/q/16684950
        //fprintf(hash_fp1, "%.*s\n", arg_size1, (char *) VARDATA(arg1) );
        //fprintf(hash_fp2, "%.*s\n", arg_size2, (char *) VARDATA(arg2) );

        // NOTE: this is a wierdo interface. why there is no constructor from an "SDBF hash" ("sdbf:..."), but only for "SDBF hash" read from a FILE*?!
        sdbf *hash_sdbf1 = new sdbf(hash_fp1);
        sdbf *hash_sdbf2 = new sdbf(hash_fp2);

        // Keep 0 in sync with sdhash.cc: sdbf_sys.sample_size
        score = (int32) hash_sdbf1->compare(hash_sdbf2, 0);

        delete hash_sdbf1;
        delete hash_sdbf2;

        fclose(hash_fp1);
        fclose(hash_fp2);

        PG_RETURN_INT32(score);
    }
    catch(exception& e)
    {
        PG_RETURN_INT32(ERROR_INT32);
    }
    catch(int e)
    {
        PG_RETURN_INT32(ERROR_INT32);
    }
}
// 
// CREATE OR REPLACE FUNCTION sdhash_hash_compare(TEXT, TEXT) RETURNS INTEGER AS 'sdhash_psql.so', 'pg_sdhash_hash_compare' LANGUAGE 'c';
//

#ifdef __cplusplus
}; /* extern "C" */
#endif 

