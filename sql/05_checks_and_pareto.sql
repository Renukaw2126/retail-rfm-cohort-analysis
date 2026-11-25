-- 05_checks_and_pareto.sql
-- Part A: retention using the SAME cohorts for every month number
-- Part B: Pareto, how much of the money comes from the top customers
-- Needs the views created by 03_rfm_v2.sql and 04_cohort.sql

-- A) Cohorts Jan 2010 to Nov 2010 only.
--    Each of these cohorts has all 12 months of data, so month numbers can be compared fairly.
SELECT month_number,
       SUM(active_customers)                                       AS active_customers,
       SUM(cohort_size)                                            AS customers_in_cohorts,
       ROUND(100.0 * SUM(active_customers) / SUM(cohort_size), 1)  AS avg_retention_pct
FROM cohort_retention
WHERE cohort_month >= TIMESTAMP '2010-01-01'
  AND cohort_month <= TIMESTAMP '2010-11-01'
  AND month_number <= 12
GROUP BY month_number
ORDER BY month_number;

-- B) Customers split into 10 equal groups by spend (decile 1 = the top 10 percent)
WITH ranked AS (
  SELECT customer_id,
         monetary,
         NTILE(10) OVER (ORDER BY monetary DESC) AS decile
  FROM rfm_scores_v2
)
SELECT decile,
       COUNT(*)                                                          AS customers,
       ROUND(SUM(monetary))                                              AS revenue,
       ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1)      AS pct_of_revenue,
       ROUND(100.0 * SUM(SUM(monetary)) OVER (ORDER BY decile)
             / SUM(SUM(monetary)) OVER (), 1)                            AS cumulative_pct
FROM ranked
GROUP BY decile
ORDER BY decile;
