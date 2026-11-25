import duckdb

con = duckdb.connect("retail.duckdb")
show = lambda sql: print(con.execute(sql).df().to_string(index=False))

pairs = """
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
),
m AS (
  SELECT p.*, c.cancel_invoice, c.cancel_date
  FROM p JOIN c
    ON p.customer_id = c.customer_id AND p.stock_code = c.stock_code
   AND p.quantity = c.qty AND p.unit_price = c.unit_price
   AND p.rn = c.rn AND c.cancel_date >= p.invoice_date
)
"""

print("1. PURCHASE LINES CANCELLED BY AN EXACT MATCH")
show(pairs + """
SELECT COUNT(*)                          AS matched_lines,
       COUNT(DISTINCT invoice_no)        AS invoices_affected,
       COUNT(DISTINCT customer_id)       AS customers_affected,
       ROUND(SUM(quantity * unit_price)) AS value_gbp,
       ROUND(MEDIAN(date_diff('minute', invoice_date, cancel_date))) AS median_minutes_to_cancel
FROM m""")

print("\n2. TEN BIGGEST MATCHED LINES")
show(pairs + """
SELECT customer_id, invoice_no, cancel_invoice, stock_code, quantity,
       ROUND(quantity * unit_price, 2) AS value_gbp,
       date_diff('minute', invoice_date, cancel_date) AS minutes_to_cancel
FROM m ORDER BY value_gbp DESC LIMIT 10""")

print("\n3. STOCK CODES THAT DO NOT LOOK LIKE NORMAL PRODUCT CODES")
show("""
SELECT stock_code, MIN(description) AS example, COUNT(*) AS n,
       ROUND(SUM(quantity * unit_price)) AS value_gbp
FROM online_retail_ii
WHERE customer_id IS NOT NULL AND quantity > 0 AND unit_price > 0
  AND invoice_no NOT LIKE 'C%'
  AND NOT regexp_matches(stock_code, '^[0-9]{5}')
GROUP BY stock_code ORDER BY n DESC LIMIT 40""")