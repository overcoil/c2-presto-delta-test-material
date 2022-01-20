# Introduction

The imperative of the so-called Dynamic Partitioning Pruning (dpp) feature it to optimize a common pattern of SQL query which 1) joins two tables; and 2) includes a highy selective predicate.

Consider the following query:

![Dynamic Partition Pruning](dpp-idea.png))

The left-hand side illustrates a direct (un-optimized) execution which will proceed to fetch all rows from the large `sales` fact table.

The right-hand side illustrates dpp's optimization which generates and injects an implicit filter into the fact table.

## TPC-DS 


SF | Table | Rows |
|:-|:-|:-|
1 | item | est. 18,000 |
1 | store_sales | 2,879,789 | 
10 | item | est. 102,000 |
10 | store_sales | 28,800,501 |
100 | item | ? |
100 | store_sales | est. 280M
1000 | item | ? |
1000 | store_sales | 2,879,987,999 |


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
|Column| Type| Extra|
|:-|:-|:-|
 ss_sold_date_sk       | integer      |       |         
 ss_sold_time_sk       | integer      |       |         
 ss_item_sk            | integer      |       |         
 ss_customer_sk        | integer      |       |         
 ss_cdemo_sk           | integer      |       |         
 ss_hdemo_sk           | integer      |       |         
 ss_addr_sk            | integer      |       |         
 ss_store_sk           | integer      |       |         
 ss_promo_sk           | integer      |       |         
 ss_ticket_number      | bigint       |       |         
 ss_quantity           | integer      |       |         
 ss_wholesale_cost     | decimal(7,2) |       |         
 ss_list_price         | decimal(7,2) |       |         
 ss_sales_price        | decimal(7,2) |       |         
 ss_ext_discount_amt   | decimal(7,2) |       |         
 ss_ext_sales_price    | decimal(7,2) |       |         
 ss_ext_wholesale_cost | decimal(7,2) |       |         
 ss_ext_list_price     | decimal(7,2) |       |         
 ss_ext_tax            | decimal(7,2) |       |         
 ss_coupon_amt         | decimal(7,2) |       |         
 ss_net_paid           | decimal(7,2) |       |         
 ss_net_paid_inc_tax   | decimal(7,2) |       |         
 ss_net_profit         | decimal(7,2) |       |         

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



## Notable Queries

### Connectivity test:

Working; scale factor 1;
```SQL
SELECT * FROM deltas3."$path$"."s3://tpc-datasets/tpcds-2.13/tpcds_sf1_delta/store_sales" LIMIT 10;
```

Working; scale factor 10;
```SQL
SELECT * FROM deltas3."$path$"."s3://tpc-datasets/tpcds-2.13/tpcds_sf10_delta/store_sales" LIMIT 10;
```

Scale factor 100: Not working; corrupted?
```SQL
trino> SELECT * FROM deltas3."$path$"."s3://tpc-datasets/tpcds-2.13/tpcds_sf100_delta/store_sales" LIMIT 10;
Query 20220119_201846_00003_wmkca failed: Error reading tail from s3://tpc-datasets/tpcds-2.13/tpcds_sf100_delta/store_sales/ss_sold_date_sk=2451478/part-01303-dd1529ec-66c4-406b-90df-1b26d563ba70.c000.snappy.parquet with length 16384
```

```SQL
SELECT count(*) FROM deltas3."$path$"."s3://tpc-datasets/tpcds_1000_dat_delta/store_sales";
```

### Prototyp
(Non-matching (scale-factor) datasets used in some queries... this is (more likely) invalid and (worse case) erroneous.)

#### THE QUERY


```SQL
WITH
  item AS (SELECT * FROM deltas3."$path$"."s3://tpc-datasets/tpcds_1000_dat_delta/item" ),
  store_sales AS (SELECT * FROM deltas3."$path$"."s3://tpc-datasets/tpcds_1000_dat_delta/store_sales" )
SELECT * 
FROM store_sales, item 
WHERE ss_item_sk = i_item_sk AND i_item_sk = 1969;
```
Does not run to completion with a single 6GB RAM worker node.

#### Related Queries

FYI: The closest occurrence of a query that remotely resembles our target pattern.

TPC-DS Query 45
```SQL
select top 100 ca_zip, ca_county, sum(ws_sales_price)
 from web_sales, customer, customer_address, date_dim, item
 where ws_bill_customer_sk = c_customer_sk
 	and c_current_addr_sk = ca_address_sk 
 	and ws_item_sk = i_item_sk 
 	and ( substr(ca_zip,1,5) in ('85669', '86197','88274','83405','86475', '85392', '85460', '80348', '81792')
 	      or 
 	      i_item_id in (select i_item_id
                             from item
                             where i_item_sk in (2, 3, 5, 7, 11, 13, 17, 19, 23, 29)
                             )
 	    )
 	and ws_sold_date_sk = d_date_sk
 	and d_qoy = 1 and d_year = 1998
 group by ca_zip, ca_county
 order by ca_zip, ca_county
 ;
```

#### Building Blocks

`s3://tpc-datasets/tpcds_1000_dat_delta` (Full TPC-DS table set for SF 1000)
```SQL
WITH
  item AS (SELECT * FROM deltas3."$path$"."s3://tpc-datasets/tpcds_1000_dat_delta/item" )
SELECT count(*) FROM item;
```

`s3://tpc-datasets/tpcds-2.13` (TPC-DS table `store_sales` for SF 1/10/100 )
```SQL
WITH
  store_sales AS (SELECT * FROM deltas3."$path$"."s3://tpc-datasets/tpcds-2.13/tpcds_sf10_delta/store_sales" )
SELECT count(*) FROM store_sales;
```

An assymmetric query in the style above:
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


### Attic

Extract table schema from Presto/Delta:
```SQL
DESCRIBE deltas3."$path$"."s3://tpc-datasets/tpcds_1000_dat_delta/item";
```

Extract table schema with [`jq`](https://stedolan.github.io/jq/download/):
```bash
$ jq -r '.metaData.schemaString' *00.json | sed 's/null//g' | jq -r '.'| less
```

Extract column names (type, etc):
```bash
$ jq -r '.metaData.schemaString' *00.json | sed 's/null//g' | jq -r '.fields[].name'
```
