
WITH nyctaxi_2019 AS (SELECT * FROM deltas3."$path$"."s3://weyland-yutani/delta/nyctaxi_2019") 

SELECT sum(trip_distance) 
FROM nyctaxi_2019 ;

