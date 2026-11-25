# Customer Segmentation and Retention Analysis (RFM + Cohort) | Online Retail II

**Author:** Renuka Wagh | [LinkedIn](https://linkedin.com/in/renuka-wagh)

A SQL analysis of two years of transactions from a UK online retailer. It answers three business questions: **who are the best customers, who is slipping away, and how many new customers come back?**

## Project status

| Part | Status |
|---|---|
| Data understanding and cleaning | Done |
| RFM segmentation (SQL) | Done |
| Cohort retention and Pareto (SQL) | Done |
| Power BI dashboard | Planned |
| AWS version (S3, Glue, Athena, Parquet) | Planned |

All analysis so far runs in SQL on DuckDB, on my laptop. The AWS version will run the same queries on Amazon Athena. I will update this page when it is done.

## Business questions

1. Which customers bring most of the revenue?
2. Which customers used to buy often but have gone quiet, and are worth winning back?
3. Of the customers who buy for the first time in a given month, how many come back later?
4. Does the business depend on a few very big customers?

## Dataset

- **Online Retail II** (UCI), downloaded from Kaggle. License: CC0.
- A UK online shop selling gift items. Many customers are wholesalers.
- 1,067,371 rows, 8 columns, from 1 Dec 2009 to 9 Dec 2011. Amounts are in pounds (£).
- One row is one product on one invoice, so one order has many rows.
- The data file is not in this repository. Download it from Kaggle and save it as `online_retail_II.csv` in the project folder.

## Data cleaning

The original table is never changed. Cleaning is done in SQL views, and every decision is written down in [`docs/data_understanding.md`](docs/data_understanding.md).

| Step | Rows removed | Rows left |
|---|---|---|
| Raw data | | 1,067,371 |
| No Customer ID | 243,007 | 824,364 |
| Cancellations (invoice starts with `C`) | 18,744 | 805,620 |
| Price zero or below | 71 | 805,549 |
| Exact duplicate rows | 26,124 | 779,425 |

Two more fixes were made in version 2 of the analysis:

- **Non-product codes removed:** postage, manual entries, carriage, bank charges, adjustments, discounts, test products (`POST`, `M`, `C2`, `BANK CHARGES`, `ADJUST`, `ADJUST2`, `PADS`, `DOT`, `D`, `TEST001`, `TEST002`).
- **Orders cancelled within 24 hours are ignored,** as if they were never placed.

**Why the 24 hour fix was needed.** While checking the top customers I found customer 16446, who "spent" £168,472 in 2 orders. In fact this customer bought 80,995 units on 9 Dec 2011 at 09:15 and cancelled the whole order at 09:27. The real purchases were only £2.90. One cancelled order had distorted Recency, Frequency and Monetary for that customer. After the fix the overall conclusions did not change (see "How the fix changed the results").

## Method

### RFM
- **Recency:** days from the customer's last invoice to 10 Dec 2011.
- **Frequency:** number of different invoices.
- **Monetary:** total spend in £ (before taking off returns made after 24 hours).
- Each is scored 1 to 5 with `PERCENT_RANK()`, so customers with the same value get the same score. Recency is scored the other way round (fewer days is better).
- Segments (my own rules, not a standard):

| Segment | Rule |
|---|---|
| Champions | R, F and M scores all 4 or 5 |
| Loyal | R and F scores 3 or more |
| New / Recent | R 4 or 5 and F 1 or 2 |
| At Risk | R 1 or 2 and F 3 or more |
| Lost | R and F both 1 or 2 |
| Needs Attention | everything else |

Rules are checked from the top, and the first match wins.

### Cohort retention
- **Cohort** = the month of a customer's first purchase. **Active** = at least one purchase in that month.
- **Retention** = customers active in month N divided by customers in the cohort.
- Only complete months are used (Dec 2009 to Nov 2011), because Dec 2011 has only 9 days.
- The Dec 2009 cohort is shown but left out of averages. The data starts that month, so it also contains old customers.

### SQL techniques used
CTEs, window functions (`PERCENT_RANK`, `NTILE`, `FIRST_VALUE`, `ROW_NUMBER`, `SUM() OVER`), date functions (`date_trunc`, `date_diff`), views, correlated `NOT EXISTS`, conditional aggregation.

## Results

5,851 customers were scored, covering £16.74M of purchases. This covers about 85% of the valid sales, because 22.8% of rows have no Customer ID and cannot be tied to a customer.

### RFM segments

| Segment | Customers | % of customers | Money (£) | % of money | Avg days since last order | Avg orders |
|---|---|---|---|---|---|---|
| Champions | 1,245 | 21.3% | 11,450,508 | 68.4% | 20 | 17.3 |
| Loyal | 1,330 | 22.7% | 2,614,007 | 15.6% | 71 | 5.7 |
| At Risk | 709 | 12.1% | 1,435,996 | 8.6% | 359 | 5.5 |
| Lost | 1,636 | 28.0% | 697,154 | 4.2% | 454 | 1.3 |
| New / Recent | 505 | 8.6% | 272,591 | 1.6% | 28 | 1.5 |
| Needs Attention | 426 | 7.3% | 269,602 | 1.6% | 107 | 1.4 |

### Revenue concentration (Pareto)

| Customers ranked by spend | Share of money |
|---|---|
| Top 10% (586 customers) | 63.3% |
| Top 20% | 76.8% |
| Top 30% | 84.7% |
| Bottom 50% | 6.6% |

The 10 biggest customers alone bring about 16% of the money.

### Cohort retention
Using the 11 cohorts from Jan to Nov 2010 (3,285 customers), which all have 12 months of data:

| Months after first purchase | 1 | 2 | 3 | 6 | 9 | 10 | 12 |
|---|---|---|---|---|---|---|---|
| Customers active again | 20.2% | 20.6% | 21.2% | 18.6% | 15.0% | 13.2% | 18.4% |

About 1 in 5 new customers buys again the month after their first purchase. Retention drifts down to its lowest point at month 10, then rises again at month 12.

### Seasonality
- Sales peak from September to November in both years. The biggest months by money are Nov 2011 (£1.51M), Nov 2010 (£1.47M) and Dec 2010 (£1.26M).
- January to November sales were £9.04M in 2010 and £9.20M in 2011, so about flat (+1.8%).
- Customers who first bought in Sep to Nov 2010 came back at a higher rate in the same months of 2011. For example, the Nov 2010 cohort had 25.1% active at month 12, against about 9.5% in several months before that. This suggests yearly seasonal buying. It is my interpretation, not proven.

### How the fix changed the results
Compared with version 1, the main story stayed the same: Champions are still about 21% of customers and bring about 68% of the money. The biggest change was in New / Recent, where the average spend fell from £873 to £540 because customer 16446 moved to Lost.

## Recommendations (suggestions, not tested)

1. **Look after the top customers.** The top 10% bring 63% of the money. Losing a few of them would hurt, so they deserve personal attention.
2. **Win back At Risk customers before the September to November season.** 709 customers spent £1.44M in the past but last bought about a year ago.
3. **Encourage a second purchase in the first month.** Only about 1 in 5 new customers returns the next month.
4. **Use low-cost, automatic outreach for Lost customers.** They are 28% of customers but only 4.2% of the money, with an average spend of about £426.
5. **Plan stock and marketing for the September to November peak.**

## Limitations

- Customers without an ID (about 15% of the money) are not in the RFM and cohort results.
- Monetary is gross. Returns made more than 24 hours after a purchase are not taken off, and a return cannot be matched to the invoice it came from.
- The cancellation matching is approximate, because the data has no line ID.
- The 24 hour limit and the segment rules are my own judgments.
- Many customers are probably wholesalers, so they behave differently from normal shoppers.
- The data covers one UK retailer, so the results may not apply to other businesses.
- Because the data starts in Dec 2009, some customers counted as "new" in early 2010 were really existing customers.

## Repository structure

```
retail-rfm-cohort/
├── README.md
├── docs/
│   └── data_understanding.md     what the data means and every cleaning decision
├── sql/
│   ├── 02_rfm.sql                RFM version 1
│   ├── 03_rfm_v2.sql             RFM version 2 (cancelled orders and test codes fixed)
│   ├── 04_cohort.sql             cohort retention
│   └── 05_checks_and_pareto.sql  same-cohort check and Pareto
├── dashboard/                    Power BI file and screenshots (coming)
├── run_sql.py                    runs a .sql file on the DuckDB database
└── 00_ to 09_ *.py               numbered scripts for loading, checks and exploration
```

## How to run

1. Download the dataset from Kaggle and save it as `online_retail_II.csv` in the project folder.
2. Install DuckDB: `pip install duckdb`
3. Load and check the data: `python 01_load_and_check.py` (this creates `retail.duckdb`)
4. Run the analysis, in this order:
   ```
   python run_sql.py sql/03_rfm_v2.sql
   python run_sql.py sql/04_cohort.sql
   python run_sql.py sql/05_checks_and_pareto.sql
   ```

## Next steps

- Build a 3 page Power BI dashboard: overview, segments, retention.
- Run the same pipeline on AWS (S3, Glue crawler, Athena), including a conversion to partitioned Parquet.
- Build a churn prediction model on top of the RFM features.
