import duckdb

con = duckdb.connect("retail.duckdb")

def show(title, sql):
    print("\n=== " + title + " ===")
    print(con.execute(sql).df().to_string(index=False))

show("4. Size of the data", """
SELECT COUNT(*)                    AS n_rows,
       COUNT(DISTINCT invoice_no)  AS invoices,
       COUNT(DISTINCT customer_id) AS customers,
       COUNT(DISTINCT stock_code)  AS products,
       COUNT(DISTINCT country)     AS countries
FROM online_retail_ii""")

show("10. Monthly trend (valid sales only)", """
SELECT strftime(invoice_date, '%Y-%m')  AS month,
       COUNT(DISTINCT invoice_no)       AS invoices,
       ROUND(SUM(quantity*unit_price))  AS revenue
FROM online_retail_ii
WHERE quantity > 0 AND unit_price > 0 AND invoice_no NOT LIKE 'C%'
GROUP BY 1 ORDER BY 1""")

show("11. How many orders does each customer have?", """
WITH o AS (
  SELECT customer_id, COUNT(DISTINCT invoice_no) AS n
  FROM online_retail_ii
  WHERE customer_id IS NOT NULL AND invoice_no NOT LIKE 'C%'
  GROUP BY 1)
SELECT CASE WHEN n = 1 THEN '1 order'
            WHEN n <= 3 THEN '2-3 orders'
            WHEN n <= 10 THEN '4-10 orders'
            ELSE '11+ orders' END AS bucket,
       COUNT(*) AS customers
FROM o GROUP BY 1 ORDER BY MIN(n)""")