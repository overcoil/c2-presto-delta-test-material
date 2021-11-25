
WITH nyctaxi_2019_part AS (SELECT * FROM "s3-dir"."$path$"."s3://weyland-yutani/delta/nyctaxi_2019_part") 

SELECT EXTRACT(month FROM pickup_datetime) as trip_month, SUM(fare_amount) 
FROM nyctaxi_2019_part 
GROUP BY EXTRACT(month FROM pickup_datetime)
ORDER BY EXTRACT(month FROM pickup_datetime);


