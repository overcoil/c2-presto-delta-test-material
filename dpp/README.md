# Introduction

The imperative of the so-called Dynamic Partitioning Pruning (dpp) feature it to optimize a common pattern of SQL query which 1) joins two tables; and 2) includes a highy selective predicate.

Consider the following query:

![Dynamic Partition Pruning](dpp-idea.png))

The left-hand side illustrates a direct (un-optimized) execution which will proceed to fetch all rows from the large `sales` fact table.

The right-hand side illustrates dpp's optimization which generates and injects an implicit filter into the fact table.

## TPC-DS table cardinalties


SF | Table | Rows |
|:-|:-|:-|
1 | item | est. 18,000 |
1 | store_sales | 2,879,789 | 
10 | item | est. 102,000 |
10 | store_sales | 28,800,501 |
100 | item | ? |
100 | store_sales | est. 280M
1000 | item | ? |
1000 | store_sales | 2.8 billion |


|Table| 
|:-|
call_center| 
catalog_page|
catalog_returns| 
catalog_sales|
customer|
customer_address|
customer_demographics|
date_dim|
household_demographics|
income_band|
inventory|
item|
promotion|
reason|
ship_mode|
store|
store_returns|
store_sales| 
time_dim|
warehouse|
web_page|
web_returns|
web_sales|
web_site|


## Table schemas

### `store_sales`
|Column| Type| Note|
|:-|:-|:-|
ss_sold_date_sk
ss_sold_time_sk
ss_item_sk
ss_customer_sk
ss_cdemo_sk
ss_hdemo_sk
ss_addr_sk
ss_store_sk
ss_promo_sk
ss_ticket_number
ss_quantity
ss_wholesale_cost
ss_list_price
ss_sales_price
ss_ext_discount_amt
ss_ext_sales_price
ss_ext_wholesale_cost
ss_ext_list_price
ss_ext_tax
ss_coupon_amt
ss_net_paid
ss_net_paid_inc_tax
ss_net_profit

### `item`
Column      |  Type   | Extra | 
|:-|:-|:-|
 i_item_sk        | bigint  |       |         
 i_item_id        | varchar |       |         
 i_rec_start_date | varchar |       |         
 i_rec_end_date   | varchar |       |         
 i_item_desc      | varchar |       |         
 i_current_price  | double  |       |         
 i_wholesale_cost | double  |       |         
 i_brand_id       | integer |       |         
 i_brand          | varchar |       |         
 i_class_id       | integer |       |         
 i_class          | varchar |       |         
 i_category_id    | integer |       |         
 i_category       | varchar |       |         
 i_manufact_id    | integer |       |         
 i_manufact       | varchar |       |         
 i_size           | varchar |       |         
 i_formulation    | varchar |       |         
 i_color          | varchar |       |         
 i_units          | varchar |       |         
 i_container      | varchar |       |         
 i_manager_id     | integer |       |         
 i_product_name   | varchar |       |         



## Sample queries

### Connectivity test:

Working; scale factor 1;
```SQL
SELECT * FROM deltas3."$path$"."s3://tpc-datasets/tpcds-2.13/tpcds_sf1_delta/store_sales" LIMIT 10;
```

Working; scale factor 10;
```SQL
SELECT * FROM deltas3."$path$"."s3://tpc-datasets/tpcds-2.13/tpcds_sf10_delta/store_sales" LIMIT 10;
```

Not working; scale factor 100;
```SQL
trino> SELECT * FROM deltas3."$path$"."s3://tpc-datasets/tpcds-2.13/tpcds_sf100_delta/store_sales" LIMIT 10;
Query 20220119_201846_00003_wmkca failed: Error reading tail from s3://tpc-datasets/tpcds-2.13/tpcds_sf100_delta/store_sales/ss_sold_date_sk=2451478/part-01303-dd1529ec-66c4-406b-90df-1b26d563ba70.c000.snappy.parquet with length 16384
```

```SQL
SELECT count(*) FROM deltas3."$path$"."s3://tpc-datasets/tpcds_1000_dat_delta/store_sales";
```

### Prototype
(Non-matching tables used.. using different scale factors which is (likely) invalid and (worse case) erroneous.)

#### The Query
```SQL
WITH
  item AS (SELECT * FROM deltas3."$path$"."s3://tpc-datasets/tpcds_1000_dat_delta/item" ),
  store_sales AS (SELECT * FROM deltas3."$path$"."s3://tpc-datasets/tpcds-2.13/tpcds_sf10_delta/store_sales" )
SELECT * 
FROM store_sales, item 
WHERE ss_item_sk = i_item_sk AND i_item_sk = 1969
LIMIT 10;
```

#### Basis
```SQL
WITH
  item AS (SELECT * FROM deltas3."$path$"."s3://tpc-datasets/tpcds_1000_dat_delta/item" )
SELECT count(*) FROM item;
```

```SQL
WITH
  store_sales AS (SELECT * FROM deltas3."$path$"."s3://tpc-datasets/tpcds-2.13/tpcds_sf10_delta/store_sales" )
SELECT count(*) FROM store_sales;
```
2 879 987 999

An assymmetric (differing scale factor across the two tables) query selective query of the style above:
```SQL
trino> WITH
  item AS (SELECT * FROM deltas3."$path$"."s3://tpc-datasets/tpcds_1000_dat_delta/item" ),
  store_sales AS (SELECT * FROM deltas3."$path$"."s3://tpc-datasets/tpcds-2.13/tpcds_sf10_delta/store_sales" )
SELECT count(*)
FROM store_sales, item 
WHERE ss_item_sk = i_item_sk AND i_item_sk = 1969;
 _col0 
-------
   602 
(1 row)

Query 20220119_205736_00013_wmkca, FINISHED, 1 node
Splits: 1,859 total, 1,859 done (100.00%)
1:48 [29.1M rows, 141MB] [269K rows/s, 1.3MB/s]
```


Basic counting of a partitioned table. 
```SQL
trino> SELECT count(*) FROM deltas3."$path$"."s3://tpc-datasets/tpcds_1000_dat_delta/store_sales";
   _col0    
------------
 2879987999 
(1 row)

Query 20220119_220720_00002_ickiu, FINISHED, 1 node
Splits: 1,860 total, 1,860 done (100.00%)
18:45 [2.88B rows, 28.8MB] [2.56M rows/s, 26.2KB/s]
```


Symmetric query selective query of the style above:
```SQL
trino> WITH
  item AS (SELECT * FROM deltas3."$path$"."s3://tpc-datasets/tpcds_1000_dat_delta/item" ),
  store_sales AS (SELECT * FROM deltas3."$path$"."s3://tpc-datasets/tpcds_1000_dat_delta/store_sales" )
SELECT count(*)
FROM store_sales, item 
WHERE ss_item_sk = i_item_sk AND i_item_sk = 1969;
```

Too much for a single worker node with 6GB RAM.

