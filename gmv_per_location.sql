WITH order_range AS (
  SELECT
    DATE_TRUNC('month', MIN(ORDER_CREATED_AT_PT)) AS start_month,
    DATE_TRUNC('month', MAX(ORDER_CREATED_AT_PT)) AS end_month
  FROM DEMO_DB.PUBLIC.PRODUCT_ANALYTICS_CASE_V2
)

,date_spine AS (
  SELECT
    DATEADD(month, SEQ4(), r.start_month) AS calendar_month
  FROM TABLE(GENERATOR(ROWCOUNT => 100))
  CROSS JOIN order_range r
  WHERE DATEADD(month, SEQ4(), r.start_month) <= r.end_month
  )

,first_order_by_location AS (
select 
location_id,
min(date_trunc('month',order_created_at_pt)) as first_order_month
from DEMO_DB.PUBLIC.PRODUCT_ANALYTICS_CASE_V2
group by 1
)

,monthly_gmv AS (
  SELECT
    LOCATION_ID,
    DATE_TRUNC('month', ORDER_CREATED_AT_PT) AS calendar_month,
    SUM(GMV) AS gmv_per_location,
    COUNT(DISTINCT order_id) AS orders_per_location
  FROM DEMO_DB.PUBLIC.PRODUCT_ANALYTICS_CASE_V2
  GROUP BY 1,2
)

,quartiles AS (
SELECT 
*,
NTILE(4) OVER (ORDER BY avg_baseline_gmv) AS baseline_quartile
FROM (
  SELECT
    m.LOCATION_ID,
    AVG(m.gmv_per_location) AS avg_baseline_gmv,
    COUNT(DISTINCT m.calendar_month) AS active_months
  FROM monthly_gmv m
  JOIN first_order_by_location f ON m.LOCATION_ID = f.LOCATION_ID
  WHERE DATEDIFF(month, f.first_order_month, m.calendar_month) BETWEEN 0 AND 2
  GROUP BY m.LOCATION_ID
  HAVING COUNT(DISTINCT m.calendar_month) >= 1
)
)

select 
calendar_month,
CASE WHEN baseline_quartile = 1 THEN 'Lowest Earning (0-25th)'
when baseline_quartile = 2 THEN 'Lower-Mid (26-50th)'
when baseline_quartile = 3 THEN 'Upper-Mid (51-75th)'
when baseline_quartile = 4 THEN 'Highest Earning (76-100th)' END AS restaurant_quartile,
count(distinct location_id) as locations,
round(avg(gmv_per_location),0) AS avg_gmv_per_location,
round(avg(orders_per_location),0) AS avg_orders_per_location
from (
    select 
    ds.calendar_month,
    mg.location_id,
    q.baseline_quartile,
    mg.gmv_per_location,
    mg.orders_per_location
    from date_spine ds
    left join monthly_gmv mg on mg.calendar_month = ds.calendar_month
    left join quartiles q on q.location_id = mg.location_id
)
group by 1,2


