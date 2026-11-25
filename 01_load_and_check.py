import duckdb

con = duckdb.connect("retail.duckdb")
q = lambda s: print(con.execute(s).fetchall())

# 1. load (columns ke naam saaf karke)
con.execute("""
CREATE OR REPLACE TABLE online_retail_ii AS
SELECT
  Invoice                        AS invoice_no,
  StockCode                      AS stock_code,
  Description                    AS description,
  Quantity                       AS quantity,
  InvoiceDate                    AS invoice_date,
  Price                          AS unit_price,
  CAST("Customer ID" AS INTEGER) AS customer_id,
  Country                        AS country
FROM read_csv_auto('online_retail_II.csv',
     types={'Invoice':'VARCHAR', 'StockCode':'VARCHAR'})
""")

print("COLUMN TYPES")
q("DESCRIBE online_retail_ii")

# 2. sanity checks
print("TOTAL ROWS (expect 1067371)")
q("SELECT COUNT(*) FROM online_retail_ii")
print("DATE RANGE (expect 2009-12-01 to 2011-12-09)")
q("SELECT MIN(invoice_date), MAX(invoice_date) FROM online_retail_ii")
print("ROWS WITH NO CUSTOMER ID")
q("SELECT COUNT(*) FROM online_retail_ii WHERE customer_id IS NULL")

# 3. cleaning ka hisaab
print("PROBLEM ROWS")
q("""
SELECT
  COUNT(*) FILTER (WHERE customer_id IS NULL)          AS no_customer,
  COUNT(*) FILTER (WHERE invoice_no LIKE 'C%')         AS cancellations,
  COUNT(*) FILTER (WHERE quantity <= 0)                AS bad_quantity,
  COUNT(*) FILTER (WHERE unit_price <= 0)              AS bad_price
FROM online_retail_ii
""")
print("INVOICE PREFIXES (letters ke saath shuru hone wale)")
q("""
SELECT LEFT(invoice_no,1) AS prefix, COUNT(*)
FROM online_retail_ii
WHERE NOT regexp_matches(invoice_no, '^[0-9]')
GROUP BY prefix
""")

# 4. clean view
con.execute("""
CREATE OR REPLACE VIEW clean_sales AS
SELECT DISTINCT
  invoice_no, stock_code, description, quantity,
  invoice_date, unit_price, customer_id, country,
  quantity * unit_price AS revenue
FROM online_retail_ii
WHERE customer_id IS NOT NULL
  AND quantity > 0
  AND unit_price > 0
  AND invoice_no NOT LIKE 'C%'
""")
print("ROWS AFTER CLEANING")
q("SELECT COUNT(*) FROM clean_sales")