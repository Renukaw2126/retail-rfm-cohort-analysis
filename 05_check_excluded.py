import duckdb

con = duckdb.connect("retail.duckdb")

print("REVENUE: customer ID wali vs bina ID wali (sirf valid sales)")
print(con.execute("""
SELECT
  CASE WHEN customer_id IS NULL THEN 'No customer ID' ELSE 'Has customer ID' END AS grp,
  COUNT(DISTINCT invoice_no)       AS invoices,
  ROUND(SUM(quantity*unit_price))  AS revenue_gbp
FROM online_retail_ii
WHERE quantity > 0 AND unit_price > 0 AND invoice_no NOT LIKE 'C%'
GROUP BY 1
""").df().to_string(index=False))

print("\nRETURNS: customer ID wale cancellation bills")
print(con.execute("""
SELECT COUNT(DISTINCT invoice_no)        AS return_invoices,
       ROUND(SUM(quantity*unit_price))   AS returned_value_gbp
FROM online_retail_ii
WHERE invoice_no LIKE 'C%' AND customer_id IS NOT NULL
""").df().to_string(index=False))