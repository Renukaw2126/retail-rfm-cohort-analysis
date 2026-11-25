import duckdb

con = duckdb.connect("retail.duckdb")
print(con.execute("""
SELECT invoice_no, invoice_date, stock_code, description,
       quantity, unit_price, ROUND(quantity * unit_price, 2) AS value
FROM online_retail_ii
WHERE customer_id = 16446
ORDER BY invoice_date
LIMIT 40
""").df().to_string(index=False))