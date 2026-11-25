import duckdb
import pandas as pd

pd.set_option("display.width", 220)
pd.set_option("display.max_columns", 50)
pd.set_option("display.max_rows", 100)

con = duckdb.connect("retail.duckdb")

def show(title, sql):
    print("\n=== " + title + " ===")
    print(con.execute(sql).df().to_string(index=False))

show("1. First 10 rows", "SELECT * FROM online_retail_ii LIMIT 10")

show("2. Random 10 rows", "SELECT * FROM online_retail_ii ORDER BY random() LIMIT 10")

show("3. Column profile (type, min, max, nulls)", "SUMMARIZE online_retail_ii")

show("4. Size of the data", """
SELECT COUNT(*) AS n_rows,
       COUNT(DISTINCT invoice_no)  AS invoices,
       COUNT(DISTINCT customer_id) AS customers,
       COUNT(DISTINCT stock_code)  AS products,
       COUNT(DISTINCT country)     AS countries
FROM online_retail_ii""")

show("5. Lines per invoice", """
SELECT ROUND(AVG(c),1) AS avg_lines, MEDIAN(c) AS median_lines, MAX(c) AS max_lines
FROM (SELECT invoice_no, COUNT(*) AS c FROM online_retail_ii GROUP BY invoice_no)""")

show("6. One full invoice (489434)", """
SELECT * FROM online_retail_ii WHERE invoice_no = '489434'""")

show("7. One customer's history (13085)", """
SELECT invoice_no, MIN(invoice_date) AS invoice_date, COUNT(*) AS lines,
       ROUND(SUM(quantity*unit_price),2) AS amount
FROM online_retail_ii WHERE customer_id = 13085
GROUP BY invoice_no ORDER BY invoice_date""")

show("8. Quantity and price spread", """
SELECT MIN(quantity) AS qty_min, quantile_cont(quantity,0.01) AS qty_p1,
       MEDIAN(quantity) AS qty_median, quantile_cont(quantity,0.99) AS qty_p99,
       MAX(quantity) AS qty_max,
       MIN(unit_price) AS price_min, MEDIAN(unit_price) AS price_median,
       quantile_cont(unit_price,0.99) AS price_p99, MAX(unit_price) AS price_max
FROM online_retail_ii""")

show("9. Top 10 countries by rows", """
SELECT country, COUNT(*) AS n_rows,
       ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER (),1) AS pct
FROM online_retail_ii GROUP BY country ORDER BY n_rows DESC LIMIT 10""")

show("10. Monthly trend (valid sales only)", """
SELECT strftime(invoice_date,'%Y-%m') AS month,
       COUNT(DISTINCT invoice_no) AS invoices,
       ROUND(SUM(quantity*unit_price)) AS revenue
FROM online_retail_ii
WHERE quantity > 0 AND unit_price > 0 AND invoice_no NOT LIKE 'C%'
GROUP BY 1 ORDER BY 1""")

show("11. How many orders does each customer have?", """
WITH o AS (
  SELECT customer_id, COUNT(DISTINCT invoice_no) AS n
  FROM online_retail_ii
  WHERE customer_id IS NOT NULL AND invoice_no NOT LIKE 'C%'
  GROUP BY 1)
SELECT CASE WHEN n=1 THEN '1 order' WHEN n<=3 THEN '2-3 orders'
            WHEN n<=10 THEN '4-10 orders' ELSE '11+ orders' END AS bucket,
       COUNT(*) AS customers
FROM o GROUP BY 1 ORDER BY MIN(n)""")

show("12. Rows with quantity <= 0", "SELECT * FROM online_retail_ii WHERE quantity <= 0 LIMIT 10")

show("13. Rows with no customer ID", """
SELECT * FROM online_retail_ii WHERE customer_id IS NULL ORDER BY random() LIMIT 10""")