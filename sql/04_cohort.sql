-- 04_cohort.sql
-- Cohort retention on Online Retail II (uses clean_sales_v2 from 03_rfm_v2.sql)
--
-- Cohort         = the month of a customer's first purchase
-- Active         = the customer has at least one purchase in that month
-- Retention %    = customers active in month N / customers in the cohort
--
-- Decisions:
--   1) Only complete months are used (Dec 2009 to Nov 2011). Dec 2011 has only 9 days.
--   2) The Dec 2009 cohort is special. The data starts then, so it also holds old customers
--      whose real first purchase was earlier. It is shown, but left out of the average.

-- 1) One row per customer per month in which the customer bought
CREATE OR REPLACE VIEW customer_months AS
SELECT DISTINCT
       customer_id,
       date_trunc('month', invoice_date) AS activity_month
FROM clean_sales_v2
WHERE invoice_date < TIMESTAMP '2011-12-01';

-- 2) For every cohort and every month number: how many customers were active
CREATE OR REPLACE VIEW cohort_retention AS
WITH first_month AS (
  SELECT customer_id, MIN(activity_month) AS cohort_month
  FROM customer_months
  GROUP BY customer_id
),
activity AS (
  SELECT f.cohort_month,
         date_diff('month', f.cohort_month, a.activity_month) AS month_number,
         COUNT(DISTINCT a.customer_id)                        AS active_customers
  FROM first_month f
  JOIN customer_months a ON a.customer_id = f.customer_id
  GROUP BY 1, 2
)
SELECT cohort_month,
       month_number,
       active_customers,
       FIRST_VALUE(active_customers) OVER (PARTITION BY cohort_month ORDER BY month_number) AS cohort_size,
       ROUND(100.0 * active_customers /
             FIRST_VALUE(active_customers) OVER (PARTITION BY cohort_month ORDER BY month_number), 1) AS retention_pct
FROM activity;

-- 3) Sanity check: both numbers must be the same
SELECT (SELECT COUNT(DISTINCT customer_id) FROM customer_months)                 AS customers_with_a_purchase,
       (SELECT SUM(active_customers) FROM cohort_retention WHERE month_number = 0) AS sum_of_cohort_sizes;

-- 4) Retention table: one row per cohort, columns = months after the first purchase
SELECT strftime(cohort_month, '%Y-%m')                                    AS cohort,
       MAX(cohort_size)                                                   AS customers,
       MAX(CASE WHEN month_number = 1  THEN retention_pct END)            AS m1,
       MAX(CASE WHEN month_number = 2  THEN retention_pct END)            AS m2,
       MAX(CASE WHEN month_number = 3  THEN retention_pct END)            AS m3,
       MAX(CASE WHEN month_number = 6  THEN retention_pct END)            AS m6,
       MAX(CASE WHEN month_number = 9  THEN retention_pct END)            AS m9,
       MAX(CASE WHEN month_number = 12 THEN retention_pct END)            AS m12
FROM cohort_retention
GROUP BY cohort_month
ORDER BY cohort_month;

-- 5) Average retention by month number (all cohorts together, Dec 2009 cohort left out)
SELECT month_number,
       SUM(active_customers)                                     AS active_customers,
       SUM(cohort_size)                                          AS customers_in_cohorts,
       ROUND(100.0 * SUM(active_customers) / SUM(cohort_size), 1) AS avg_retention_pct
FROM cohort_retention
WHERE cohort_month > TIMESTAMP '2009-12-01'
  AND month_number <= 12
GROUP BY month_number
ORDER BY month_number;
