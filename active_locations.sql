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

,agg_active_locations AS (
select 
date_trunc('month',order_created_at_pt) AS order_month,
count(distinct case when fol.first_order_month = date_trunc('month',pac.order_created_at_pt) then pac.location_id end) as new_active_locations,
count(distinct case when fol.first_order_month < date_trunc('month',pac.order_created_at_pt) then pac.location_id end) as existing_active_locations
from DEMO_DB.PUBLIC.PRODUCT_ANALYTICS_CASE_V2 pac
inner join first_order_by_location fol on fol.location_id = pac.location_id
group by 1
)

select 
calendar_month,
coalesce(new_active_locations,0) AS new_active_locations,
coalesce(existing_active_locations,0) AS existing_active_locations,
SUM(new_active_locations+existing_active_locations) OVER (ORDER BY calendar_month
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS rolling_total_active_locations
from date_spine ds
left join agg_active_locations ON agg_active_locations.order_month = ds.calendar_month
order by 1
