
WITH nyctaxi_2019 AS (SELECT * FROM deltas3."$path$"."s3://weyland-yutani/delta/nyctaxi_2019") 

SELECT EXTRACT(month FROM pickup_datetime) as trip_month, SUM(fare_amount) 
FROM nyctaxi_2019 
GROUP BY EXTRACT(month FROM pickup_datetime)
ORDER BY EXTRACT(month FROM pickup_datetime);


