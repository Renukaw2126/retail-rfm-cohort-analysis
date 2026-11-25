-- 03_rfm_v2.sql
-- RFM version 2. Same idea as 02_rfm.sql, with two fixes found while checking the data:
--   1) four more non-product codes are excluded (C2, ADJUST2, TEST001, TEST002)
--   2) purchases cancelled within 24 hours by an exact matching cancellation are ignored
-- Reference date for recency = 2011-12-10 (one day after the last transaction date)

-- 1) Match each cancellation line with the purchase line it cancels
--    (same customer, product, quantity and price, cancelled after the purchase)
CREATE OR REPLACE VIEW matched_cancellations AS
WITH base AS (
  SELECT DISTINCT * FROM online_retail_ii WHERE customer_id IS NOT NULL
),
p AS (
  SELECT invoice_no, customer_id, stock_code, quantity, unit_price, invoice_date,
         ROW_NUMBER() OVER (PARTITION BY customer_id, stock_code, quantity, unit_price
                            ORDER BY invoice_date) AS rn
  FROM base
  WHERE quantity > 0 AND unit_price > 0 AND invoice_no NOT LIKE 'C%'
),
c AS (
  SELECT invoice_no AS cancel_invoice, customer_id, stock_code,
         -quantity AS qty, unit_price, invoice_date AS cancel_date,
         ROW_NUMBER() OVER (PARTITION BY customer_id, stock_code, -quantity, unit_price
                            ORDER BY invoice_date) AS rn
  FROM base
  WHERE quantity < 0 AND unit_price > 0 AND invoice_no LIKE 'C%'
)
SELECT p.invoice_no, p.customer_id, p.stock_code, p.quantity, p.unit_price,
       p.invoice_date, c.cancel_invoice, c.cancel_date,
       date_diff('minute', p.invoice_date, c.cancel_date) AS minutes_to_cancel
FROM p JOIN c
  ON p.customer_id = c.customer_id
 AND p.stock_code  = c.stock_code
 AND p.quantity    = c.qty
 AND p.unit_price  = c.unit_price
 AND p.rn          = c.rn
 AND c.cancel_date >= p.invoice_date;

-- 2) How fast were these purchases cancelled? (used to check the 24 hour rule)
SELECT CASE WHEN minutes_to_cancel <= 60    THEN '1. within 1 hour'
            WHEN minutes_to_cancel <= 1440  THEN '2. within 24 hours'
            WHEN minutes_to_cancel <= 10080 THEN '3. within 7 days'
            WHEN minutes_to_cancel <= 43200 THEN '4. within 30 days'
            ELSE '5. later than 30 days' END  AS time_to_cancel,
       COUNT(*)                               AS lines,
       COUNT(DISTINCT invoice_no)             AS invoices,
       ROUND(SUM(quantity * unit_price))      AS value_gbp
FROM matched_cancellations
GROUP BY 1
ORDER BY 1;

-- 3) Clean purchases, version 2
CREATE OR REPLACE VIEW clean_sales_v2 AS
SELECT s.*
FROM (
  SELECT DISTINCT
    invoice_no, stock_code, description, quantity, invoice_date,
    unit_price, customer_id, country,
    quantity * unit_price AS revenue
  FROM online_retail_ii
  WHERE customer_id IS NOT NULL
    AND quantity > 0
    AND unit_price > 0
    AND invoice_no NOT LIKE 'C%'
    AND UPPER(stock_code) NOT IN ('POST','M','C2','ADJUST','ADJUST2','BANK CHARGES',
                                  'PADS','DOT','D','TEST001','TEST002')
) s
WHERE NOT EXISTS (
  SELECT 1 FROM matched_cancellations m
  WHERE m.minutes_to_cancel <= 1440
    AND m.invoice_no = s.invoice_no
    AND m.stock_code = s.stock_code
    AND m.quantity   = s.quantity
    AND m.unit_price = s.unit_price
);

-- 4) R, F, M per customer, scored 1 to 5, then segment
CREATE OR REPLACE VIEW rfm_scores_v2 AS
WITH rfm_base AS (
  SELECT customer_id,
         date_diff('day', CAST(MAX(invoice_date) AS DATE), DATE '2011-12-10') AS recency_days,
         COUNT(DISTINCT invoice_no) AS frequency,
         ROUND(SUM(revenue), 2)     AS monetary
  FROM clean_sales_v2
  GROUP BY customer_id
),
scored AS (
  SELECT *,
    CAST(LEAST(5, FLOOR(5 * PERCENT_RANK() OVER (ORDER BY recency_days DESC)) + 1) AS INTEGER) AS r_score,
    CAST(LEAST(5, FLOOR(5 * PERCENT_RANK() OVER (ORDER BY frequency))            + 1) AS INTEGER) AS f_score,
    CAST(LEAST(5, FLOOR(5 * PERCENT_RANK() OVER (ORDER BY monetary))             + 1) AS INTEGER) AS m_score
  FROM rfm_base
)
SELECT *,
  CASE
    WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
    WHEN r_score >= 3 AND f_score >= 3                  THEN 'Loyal'
    WHEN r_score >= 4 AND f_score <= 2                  THEN 'New / Recent'
    WHEN r_score <= 2 AND f_score >= 3                  THEN 'At Risk'
    WHEN r_score <= 2 AND f_score <= 2                  THEN 'Lost'
    ELSE 'Needs Attention'
  END AS segment
FROM scored;

-- 5) Summary by segment (compare with the first RFM result)
SELECT segment,
       COUNT(*)                                                        AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)              AS pct_customers,
       ROUND(SUM(monetary))                                            AS revenue,
       ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1)    AS pct_revenue,
       ROUND(AVG(recency_days))                                        AS avg_recency_days,
       ROUND(AVG(frequency), 1)                                        AS avg_orders,
       ROUND(AVG(monetary))                                            AS avg_spend
FROM rfm_scores_v2
GROUP BY segment
ORDER BY revenue DESC;

-- 6) Top 10 customers by spend
SELECT * FROM rfm_scores_v2 ORDER BY monetary DESC LIMIT 10;

-- 7) The two customers with huge cancelled orders (empty result = no purchases left)
SELECT * FROM rfm_scores_v2 WHERE customer_id IN (16446, 12346);
