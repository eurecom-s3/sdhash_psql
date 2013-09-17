
PG_CPPFLAGS = -I.

MODULE_big = sdhash_psql
OBJS = sdhash_psql.o
# NOTE: imho, '-lfuzzy' is a really fuzzy and confusing name for a library. why not ssdeep, fuzzyh, fuzzyhash, fuzzydeep?
#SHLIB_LINK = -lfuzzy

# DATA_built = pg_trgm.sql
# DATA = uninstall_pg_trgm.sql
# DOCS = README.pg_trgm
# REGRESS = pg_trgm


ifdef USE_PGXS
PGXS := $(shell pg_config --pgxs)
include $(PGXS)
else
subdir = contrib/sdhash_psql
top_builddir = ../..
include $(top_builddir)/src/Makefile.global
include $(top_srcdir)/contrib/contrib-global.mk
endif
