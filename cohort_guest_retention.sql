WITH first_order AS (
  SELECT
    GUEST_ID,
    LOCATION_ID,
    DATE_TRUNC('month', MIN(ORDER_CREATED_AT_PT)) AS cohort_month
  FROM DEMO_DB.PUBLIC.PRODUCT_ANALYTICS_CASE_V2
  GROUP BY 1, 2
),

orders AS (
  SELECT
    GUEST_ID,
    LOCATION_ID,
    DATE_TRUNC('month', ORDER_CREATED_AT_PT) AS order_month
  FROM DEMO_DB.PUBLIC.PRODUCT_ANALYTICS_CASE_V2
),

cohort_activity AS (
  SELECT
    f.cohort_month,
    o.order_month,
    DATEDIFF(month, f.cohort_month, o.order_month) AS months_since_first,
    o.GUEST_ID
  FROM orders o
  JOIN first_order f
    ON o.GUEST_ID = f.GUEST_ID
   AND o.LOCATION_ID = f.LOCATION_ID
  WHERE o.order_month >= f.cohort_month
),

cohort_counts AS (
  SELECT
    cohort_month,
    months_since_first,
    COUNT(DISTINCT GUEST_ID) AS retained_guests
  FROM cohort_activity
  GROUP BY 1, 2
),

cohort_sizes AS (
  SELECT
    cohort_month,
    COUNT(DISTINCT GUEST_ID) AS cohort_size
  FROM first_order
  GROUP BY 1
)

SELECT
  c.cohort_month,
  c.months_since_first,
  c.retained_guests,
  s.cohort_size,
  c.retained_guests / NULLIF(s.cohort_size, 0) AS retention_rate
FROM cohort_counts c
JOIN cohort_sizes s USING (cohort_month)
ORDER BY cohort_month, months_since_first;
