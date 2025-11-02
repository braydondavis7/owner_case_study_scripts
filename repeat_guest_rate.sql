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

,first_order_by_location_guest AS (
select 
location_id,
guest_id,
min(date_trunc('day',order_created_at_pt)) as first_order_date
from DEMO_DB.PUBLIC.PRODUCT_ANALYTICS_CASE_V2
group by 1,2
)

,repeat_orders AS (
  SELECT
    p.LOCATION_ID,
    p.GUEST_ID,
    DATE_TRUNC('month', p.ORDER_CREATED_AT_PT) AS order_month,
    CASE
      WHEN p.ORDER_CREATED_AT_PT::date > f.first_order_date THEN 1 ELSE 0
    END AS is_repeat
  FROM DEMO_DB.PUBLIC.PRODUCT_ANALYTICS_CASE_V2 p
  JOIN first_order_by_location_guest f
    ON p.LOCATION_ID = f.LOCATION_ID
   AND p.GUEST_ID = f.GUEST_ID
)

  SELECT
    order_month,
    COUNT(DISTINCT CASE WHEN is_repeat = 1 THEN GUEST_ID END) AS repeat_guests,
    COUNT(DISTINCT GUEST_ID) AS total_guests,
    COUNT(DISTINCT CASE WHEN is_repeat = 1 THEN GUEST_ID END)
      / NULLIF(COUNT(DISTINCT GUEST_ID), 0) AS repeat_guest_rate
  FROM repeat_orders
  GROUP BY 1

  

