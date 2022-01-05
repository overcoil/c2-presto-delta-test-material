#!/usr/bin/env bash

sed s/ZZ/$1/g extract-param.awk > extract.awk
awk -f extract.awk tpcdsq-raw/tpcds-ansi-all.sql > tpcdsq-raw/q$1.sql
cat rtu/delta-cte.sql tpcdsq-raw/q$1.sql > rtu/q$1.sql
ls -l rtu/q$1.sql
echo Review your query before use.
