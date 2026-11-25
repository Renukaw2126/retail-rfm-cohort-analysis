import duckdb

con = duckdb.connect("retail.duckdb")
q = lambda s: print(con.execute(s).fetchall())

base = "SELECT COUNT(*) FROM online_retail_ii"
steps = [
  ("Start", base),
  ("After removing no customer ID", base + " WHERE customer_id IS NOT NULL"),
  ("After removing cancellations (C)", base + " WHERE customer_id IS NOT NULL AND invoice_no NOT LIKE 'C%'"),
  ("After removing qty<=0 / price<=0", base + " WHERE customer_id IS NOT NULL AND invoice_no NOT LIKE 'C%' AND quantity > 0 AND unit_price > 0"),
  ("After removing exact duplicates", "SELECT COUNT(*) FROM clean_sales"),
]
for name, sql in steps:
    print(name, "->", con.execute(sql).fetchone()[0])

print("INVOICES STARTING WITH A")
q("SELECT * FROM online_retail_ii WHERE invoice_no LIKE 'A%'")

print("NON-PRODUCT STOCK CODES (no digits) in clean_sales")
q("""
SELECT stock_code, COUNT(*) AS n, ROUND(SUM(revenue)) AS revenue
FROM clean_sales
WHERE NOT regexp_matches(stock_code, '[0-9]')
GROUP BY stock_code ORDER BY n DESC
""")