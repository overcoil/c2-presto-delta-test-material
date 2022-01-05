
WITH nyctaxi_2019_part AS (SELECT * FROM deltas3."$path$"."s3://weyland-yutani/delta/nyctaxi_2019_part") 

SELECT sum(trip_distance) 
FROM nyctaxi_2019_part ;

