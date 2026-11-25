-- RFM segmentation on Online Retail II
-- Reference date = 2011-12-10 (one day after the last transaction date)

-- 1) Clean purchases only
CREATE OR REPLACE VIEW clean_sales_final AS
SELECT DISTINCT
  invoice_no, stock_code, description, quantity, invoice_date,
  unit_price, customer_id, country,
  quantity * unit_price AS revenue
FROM online_retail_ii
WHERE customer_id IS NOT NULL
  AND quantity > 0
  AND unit_price > 0
  AND invoice_no NOT LIKE 'C%'
  AND UPPER(stock_code) NOT IN ('POST','M','ADJUST','BANK CHARGES','PADS','DOT','D');

-- 2) R, F, M per customer, scored 1 to 5, then segment
CREATE OR REPLACE VIEW rfm_scores AS
WITH rfm_base AS (
  SELECT customer_id,
         date_diff('day', CAST(MAX(invoice_date) AS DATE), DATE '2011-12-10') AS recency_days,
         COUNT(DISTINCT invoice_no) AS frequency,
         ROUND(SUM(revenue), 2)     AS monetary
  FROM clean_sales_final
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

-- 3) Summary by segment
SELECT segment,
       COUNT(*)                                                        AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)              AS pct_customers,
       ROUND(SUM(monetary))                                            AS revenue,
       ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1)    AS pct_revenue,
       ROUND(AVG(recency_days))                                        AS avg_recency_days,
       ROUND(AVG(frequency), 1)                                        AS avg_orders,
       ROUND(AVG(monetary))                                            AS avg_spend
FROM rfm_scores
GROUP BY segment
ORDER BY revenue DESC;

-- 4) Top 10 customers by spend
SELECT * FROM rfm_scores ORDER BY monetary DESC LIMIT 10;