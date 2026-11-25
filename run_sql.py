import duckdb, sys

con = duckdb.connect("retail.duckdb")
sql = open(sys.argv[1], encoding="utf-8").read()

for stmt in sql.split(";"):
    body = "\n".join(l for l in stmt.splitlines() if not l.strip().startswith("--")).strip()
    if not body:
        continue
    res = con.execute(body)
    if body.upper().startswith(("SELECT", "WITH")):
        print(res.df().to_string(index=False))
        print()