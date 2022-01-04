
WITH customer AS (SELECT * FROM deltas3."$path$"."s3://tpc-datasets/tpcds_1000_dat_delta/customer") 

SELECT * FROM customer LIMIT 25;

