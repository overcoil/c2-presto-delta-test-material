
WITH nyctaxi_2019_part AS (SELECT * FROM trinodpp."$path$"."s3://weyland-yutani/delta/nyctaxi_2019_part") 
SELECT * FROM nyctaxi_2019_part LIMIT 25;

