import duckdb

con = duckdb.connect("retail.duckdb")

print(con.execute("""
SELECT invoice_no LIKE 'C%'  AS is_cancellation,
       customer_id IS NULL   AS no_customer_id,
       COUNT(*)              AS n_rows
FROM online_retail_ii
WHERE quantity <= 0
GROUP BY 1, 2
ORDER BY n_rows DESC
""").df().to_string(index=False))