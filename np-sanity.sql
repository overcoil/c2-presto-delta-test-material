
WITH nyctaxi_2019 AS (SELECT * FROM "s3-dir"."$path$"."s3://weyland-yutani/delta/nyctaxi_2019") 

SELECT * FROM nyctaxi_2019 LIMIT 25;

