#!/usr/bin/env bash

#
# usage: extract.sh N
#  N is the index (1-99) from the TPC-DS query set
#
# delta-cte.sql is populated fragment that points to your S3 bucket where the TPC-DS dataset resides
# 
# the output is saved at rtu/qN.sql
# 
sed s/ZZ/$1/g extract-param.awk > .extract.awk
awk -f .extract.awk raw/tpcds-ansi-all.sql > raw/q$1.sql
cat rtu/delta-cte.sql raw/q$1.sql > rtu/q$1.sql
ls -l rtu/q$1.sql
echo Review your query before use.
