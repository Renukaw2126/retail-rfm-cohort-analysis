# Data Notes: Online Retail II

My working notes for the customer segmentation project (RFM and cohort analysis).
**Confirmed** means I checked it in my own query output. **Pending** means I still need to check it.

---

## 1. About the data

- **Name:** Online Retail II (UCI), downloaded from Kaggle. License: CC0 (free to use).
- **Business:** a UK online shop that sells gift items. Many of its customers are wholesalers (businesses that buy in bulk).
- **Time period:** 1 Dec 2009 to 9 Dec 2011 (Confirmed).
- **Size:** 1,067,371 rows and 8 columns. These rows hold 53,628 invoices, 5,942 different customer IDs, 5,305 different product codes and 43 countries (all Confirmed).
- **Currency:** pounds (£), not rupees.

---

## 2. What one row means

- **One row = one product on one bill.**
- **One invoice = one bill = one order.** A bill can have many products, so it has many rows.
- That is why there are far more rows (about 10.7 lakh) than invoices (53,628, Confirmed).
- The invoice number repeats on every row of the same bill. So it cannot be the primary key of this table.
- **Rule for later:** to count how many times a customer ordered, count **distinct invoices**, not rows.

---

## 3. Columns

| Column | What it means |
|---|---|
| `invoice_no` | Bill number. Starts with **C** = cancelled order. Starts with **A** = accounting adjustment |
| `stock_code` | Product code. Mostly 5 digits. A letter at the end means a variant, like another colour (79323P = pink, 79323W = white) |
| `description` | Product name |
| `quantity` | How many units. A minus sign means the item was returned |
| `invoice_date` | Date and time of the bill, like `2009-12-01 07:45:00` |
| `unit_price` | Price of one unit, in £ |
| `customer_id` | Customer number. Some are empty |
| `country` | Customer's country |

Extra notes:
- I loaded `stock_code` as text because some codes have letters, like `17091A`.
- I did not change the date format. It was already in the standard format.
- I made one extra column: `revenue` = `quantity x unit_price`.

---

## 4. What I noticed

1. **Almost all rows are from the UK** (91.9% of rows). Then EIRE 1.7%, Germany 1.7%, France 1.3%. So country will not tell us much here. (This is a share of rows, not of customers or money.)
2. **About 1 in 5 rows has no customer ID** (243,007 rows, 22.8%). We cannot tell who bought these.
3. **Cancelled orders start with `C`** (19,494 rows) and have minus quantities.
4. **Six invoices start with `A`.** These are "Adjust bad debt" entries, not real sales. They have no customer ID, and some have big values like -£53,594.
5. **Some codes are not products.** Examples: postage, bank charges, manual entries.
6. **26,124 rows are exact copies of other rows.** There is no line number, so I cannot tell if they are real double entries or the same item scanned twice.
7. **Sales peak from September to November** in both years (Confirmed, see 6A). November is the biggest month.
8. **Some quantities and prices are extreme** (very big or very negative). I still need to look at these.
9. **Most customers come back.** About 72% of customers ordered 2 or more times (Confirmed, see 6B). So a cohort retention table will have real data in it.
10. **Sales were about flat between the two years.** January to November 2010 was £9.04M and the same months of 2011 were £9.20M (+1.8%). This is my own calculation from the monthly numbers.
11. **December and January bills are bigger.** The average bill is about £810 in Dec 2010 and £780 in Dec 2011 (only 9 days), against about £430 to £580 in most other months. January is also higher (about £590 in 2010 and £640 in 2011). Dec 2009 is not like this (about £491). I do not know why (see 6A).

---

## 5. What I removed and why

The original table is never changed. I only filter it using views (`clean_sales` and `clean_sales_final`), so I can always go back.

### Step by step (Confirmed)

| Step | What I removed | Rows removed | Rows left |
|---|---|---|---|
| Start | Nothing | n/a | 1,067,371 |
| 1 | Rows with no customer ID | 243,007 | 824,364 |
| 2 | Cancelled orders (`C`) | 18,744 | 805,620 |
| 3 | Price zero or below zero | 71 | 805,549 |
| 4 | Exact copies of rows | 26,124 | 779,425 |
| 5 | Non-product codes | pending | pending |

Good to know:
- Step 2 shows 18,744, not 19,494, because 750 cancelled rows had no customer ID and were already removed in step 1.
- All 22,950 rows with minus quantity were already removed by steps 1 and 2. So I did not need a separate quantity rule.
- I have not looked at the 71 price rows yet. I think they are free items or entry mistakes, but that is a guess.

### Why I removed each one

| Removed | Why | Can still be used for |
|---|---|---|
| No customer ID | RFM is about customers. If we do not know who bought, we cannot count them | Total sales, product sales, monthly trend |
| Cancelled orders | A return is not a purchase. It would make orders and spending look wrong | Return analysis |
| Price zero or below | Not real sales | n/a |
| Exact copies | Probably repeated rows | I will re-check this (see below) |

### Codes that are not products (Confirmed)

| Code | Meaning | Rows | Money (£) |
|---|---|---|---|
| POST | Postage | 1,803 | 124,648 |
| M | Manual entry | 681 | 151,778 |
| DOT | Dotcom postage | 16 | 11,906 |
| ADJUST | Adjustment | 32 | 3,539 |
| BANK CHARGES | Bank fee | 31 | 450 |
| D | Discount | 5 | 398 |
| PADS | Unclear | 17 | 0 |
| C2 | Carriage (shipping charge) | 253 | 12,796 |
| ADJUST2 | Adjustment | 3 | 731 |
| TEST001 | Test product | 9 | 225 |
| TEST002 | Test product | 1 | 1 |

I will leave these out of customer spending, because they are not products the customer chose. This is my own decision. Some analysts keep postage. The last four rows (C2, ADJUST2, TEST001, TEST002) were found later with `09_cancelled_pairs.py`. Their counts come from the raw rows, before copies were removed, so they are slightly higher. Together they are only about £13.8k. `SP1002` ("KID'S CHALKBOARD/EASEL", 2 rows, £15) looks like a real product with an odd code, so I keep it (my judgment).

### The copies question (open)
- I removed 26,124 exact copies (about 3.2%).
- This does not change recency or frequency. It may change the total money (monetary).
- To do: compare total money with and without removing copies.

---

## 6. How much of the business RFM will cover (Confirmed)

This is for valid sales only, before removing copies and non-product codes.

| Group | Bills | Money (£) | Average bill (£) |
|---|---|---|---|
| Has customer ID | 36,969 | 17,743,429 | about 480 |
| No customer ID | 3,108 | 3,229,165 | about 1,039 |

- RFM will cover about **85% of the money** (84.6%) and **92% of the bills** (92.2%).
- Bills without a customer ID are fewer (7.8%) but about twice as big. I do not know why. They may be bulk orders, but that is only a guess.
- Customers with an ID returned about **£1.1 million** of goods in 7,901 cancelled bills. That is about 6% of their sales.

---

## 6A. Sales by month (Confirmed)

Valid sales only (no cancellations, price above zero), for all customers including those with no ID. Copies and non-product codes are not removed yet. All months add up to about £20.97M, which matches the total in Section 6, so the numbers agree.

- **Top 3 months by money:** Nov 2011 (£1.51M), Nov 2010 (£1.47M), Dec 2010 (£1.26M).
- **Strong season:** September to December in both years. Sep, Oct and Nov are each clearly higher than the months before them.
- **Weakest months:** Feb 2011 (£0.52M), Apr 2011 (£0.54M), Feb 2010 (£0.55M).
- **Bigger bills in December and January.** Average bill = money / bills (my own calculation). Dec 2010 = about £810 (1,559 bills). Dec 2011 = about £780 (819 bills, 9 days only). Jan 2010 = about £590 and Jan 2011 = about £640. Most other months are between about £430 and £580. So these months have fewer bills, but each bill is bigger. The reason is unknown. Ideas to test: more bulk or wholesale orders before the holidays, a few very large bills pulling the average up, or more bills without a customer ID (those bills are about twice as big). The Kaggle chart also shows very few rows in late December and early January, so the shop may have closed for the holidays (my guess).
- **December 2011 is not a full month.** The data ends on 9 December, so it cannot be compared with other months.
- **Year on year:** January to November 2010 = £9.04M, January to November 2011 = £9.20M. That is about flat (+1.8%).

---

## 6B. How many orders each customer made (Confirmed)

Purchase bills only (cancellations not counted), customers with an ID.

| Orders | Customers | Share |
|---|---|---|
| 1 order | 1,626 | 27.6% |
| 2 to 3 orders | 1,608 | 27.3% |
| 4 to 10 orders | 1,771 | 30.1% |
| 11 or more orders | 876 | 14.9% |
| **Total** | **5,881** | |

- 4,255 customers (about 72%) ordered at least twice. This is why Online Retail II is good for cohort retention.
- The average is about 6 orders per customer (36,969 valid bills / 5,881 customers), but this is pulled up by the 876 heavy buyers. They may be wholesalers (my guess).
- Section 4 shows 5,942 customers and this table shows 5,881. The difference of 61 customers is probably people who only have cancelled bills (my reading of the numbers, not yet checked).
- Because 27.6% of customers have exactly 1 order, they will all get the same Frequency score in RFM.

---

## 7. Limits of this analysis

- RFM only covers customers with an ID (about 85% of the money), not the whole business.
- "Monetary" means total bought, before taking away returns.
- We cannot match a return to the bill it came from.
- Many customers are wholesalers, so they are not like normal shoppers.
- This is one UK shop, so results may not match other businesses.
- December 2011 has only 9 days of data.
- Customers with only 1 order include people who started buying late in 2011. They have had little time to come back, so "never returned" is not always "lost".

---

## 8. Still to check

- [x] Total rows, bills, customers, products (Section 4 of `00_explore.py`)
- [x] How many orders each customer made (Section 11). This tells us how many customers came back
- [x] Monthly sales and the top 3 months (Section 10)
- [ ] What the 71 price rows are
- [x] Money with and without exact copies (about £0.37M, about 2% of the money, estimated from the RFM total, see Section 10)
- [x] Any other non-product codes (found C2, ADJUST2, TEST001, TEST002, see 5.3)
- [ ] Extreme quantities and prices
- [ ] Average and median bill by month, split by bills with and without a customer ID (`07_avg_bill_by_month.py`)
- [x] Customer 16446 checked (see Section 10, problem 1)
- [x] Measure how many purchase lines are cancelled by an exact matching cancellation line (see the end of Section 10)
- [x] Run `sql/03_rfm_v2.sql` (ignores purchases cancelled within 24 hours and excludes 4 more codes) and compare with the first RFM result (see the end of Section 10)
- [ ] Quick check with other time limits (1 hour and 7 days) to see if the segments change
- [x] Cohort retention run (`sql/04_cohort.sql`, see Section 11)
- [x] Retention using the same cohorts for every month number, and the Pareto table of customer spend (see the end of Section 11 and Section 12)
- [x] Look for other test or non-product stock codes like `TEST001` (see 5.3)
- [ ] Median spend per segment (averages are pulled up by very big customers)

---

## 9. Plan for RFM (now run, results in Section 10)

- **Today's date for the calculation:** 10 Dec 2011 (one day after the last sale).
- **Recency** = days since the last bill. **Frequency** = number of different bills. **Monetary** = total money spent in £.
- Each is scored 1 to 5 using `PERCENT_RANK()`, so customers with the same value get the same score. Because 27.6% of customers have only 1 order, the Frequency bands will not be exactly 20% each.
- The segment names (Champions, Loyal, New/Recent, At Risk, Lost, Needs Attention) are my own rules, not a standard. I will list the rules in the README.

---

## 10. First RFM results (Confirmed, from `sql/02_rfm.sql`)

- Customers scored: **5,853**.
- Money covered: **£17.08M** (total purchases after all the cleaning rules in Section 5, before taking away returns).

| Segment | Customers | % of customers | Money (£) | % of money | Avg days since last bill | Avg orders | Avg spend (£) |
|---|---|---|---|---|---|---|---|
| Champions | 1,246 | 21.3% | 11,526,284 | 67.5% | 20 | 17.4 | 9,251 |
| Loyal | 1,331 | 22.7% | 2,659,331 | 15.6% | 71 | 5.7 | 1,998 |
| At Risk | 713 | 12.2% | 1,532,078 | 9.0% | 359 | 5.5 | 2,149 |
| Lost | 1,633 | 27.9% | 692,092 | 4.1% | 454 | 1.3 | 424 |
| New / Recent | 506 | 8.6% | 441,697 | 2.6% | 27 | 1.5 | 873 |
| Needs Attention | 424 | 7.2% | 230,603 | 1.3% | 107 | 1.4 | 544 |

### What the table shows
- **A small group brings most of the money.** Champions are 21.3% of customers and bring 67.5% of the money. Champions and Loyal together are 44.0% of customers and bring 83.1% (my addition).
- **Lost is the biggest group** (27.9% of customers) but brings only 4.1% of the money. They bought 1.3 times on average and spent about £424.
- **At Risk is a group worth watching.** 713 customers who used to order often (5.5 orders, about £2,149 each) but whose last bill was about 359 days ago. Together they spent £1.53M.
- **A few customers matter a lot.** The top 10 customers spent £2.76M, which is about 16.2% of all the money. The biggest one (ID 18102) spent about £0.58M (about 3.4%). I do not know who they are; they may be wholesalers (my guess). These two figures are my own calculation from the top 10 list.
- Averages like "£9,251 per Champion" are pulled up by these very big customers. The median would be fairer (still to do).

### Checks that agree
- Money here (£17.08M) is lower than the £17.74M in Section 6. The gap is about £0.66M: about £0.29M is non-product codes (Section 5.3) and about £0.37M is exact copies (my estimate by subtraction, about 2%).
- Customers here (5,853) are 28 fewer than in 6B (5,881). Probably their only purchases were removed by the cleaning rules (my reading, not checked).

### Problems I found
1. **Customer 16446 (confirmed with `08_check_16446.py`).** On 2011-12-09 at 09:15 this customer bought 80,995 units of "PAPER CRAFT , LITTLE BIRDIE" at £2.08 each (£168,469.60). At 09:27 the same day, 12 minutes later, the whole order was cancelled (invoice C581484, -£168,469.60). Our rules removed the cancellation but kept the purchase. This customer's real purchases are only £2.90 (bought on 2011-05-18), but RFM shows Recency 1 day, Frequency 2 and Monetary £168,472.50. **So one cancelled order can distort all three RFM numbers, not only Monetary.** This is fixed in version 2 (see the end of this section).
2. **The segment rules ignore Monetary.** A customer who spent £168k in 2 orders and a customer who spent £873 in 2 orders both fall in "New / Recent".
3. **Three of the top 10 customers had exactly 145 orders** (IDs 18102, 14646, 14156). After version 2, customer 14156 has 144 orders (one order was cancelled within 24 hours), so this was a coincidence.
4. **A test product exists.** The stock code `TEST001` ("This is a test product.") appears in customer 16446's rows. It is not on the exclusion list in Section 5.3, so other test or non-product codes may still be in the data. Not yet checked.

### Cancelled purchases (Confirmed, from `09_cancelled_pairs.py`)

I matched each cancellation line to a purchase line of the same customer, product, quantity and price, where the cancellation came after the purchase. This is approximate, because the data has no line ID.

- **6,086 purchase lines** (in 3,138 bills, for 1,512 customers) have a matching cancellation. That is about 1 in 4 of the scored customers, and about £587,580 of purchases.
- **The typical match is a return weeks later, not a quick mistake.** The median time between purchase and cancellation is 24,263 minutes (about 17 days).
- **The biggest matches were cancelled within minutes.** Customer 16446 (£168,470, 12 minutes) and customer 12346 (£77,184, 16 minutes). Two "M" (manual) entries of about £9.0k and £7.0k were cancelled after 1 and 4 minutes.
- **Some are real returns much later.** Customer 15749 returned several lines (invoice C550456) about 97 days after buying.

Decision (my judgment): removing every matched purchase would also remove real purchases that were returned later, and a customer who bought and returned still showed interest. So version 2 ignores only purchases cancelled **within 24 hours**, as if the order was never placed. The 24 hour limit is a choice, and the time table in `sql/03_rfm_v2.sql` is there to check it. Money is still gross for returns made after 24 hours.

### RFM version 2 results (Confirmed, from `sql/03_rfm_v2.sql`)

Two fixes were made: purchases cancelled within 24 hours are ignored, and four more non-product codes are excluded (C2, ADJUST2, TEST001, TEST002).
Customers scored: **5,851** (2 fewer than version 1). Money covered: **£16.74M**, about £0.34M (2%) less than version 1.

**How fast were matched purchases cancelled?**

| Time to cancel | Lines | Money (£) |
|---|---|---|
| Within 1 hour | 800 | 332,055 |
| Within 24 hours | 290 | 34,587 |
| Within 7 days | 1,039 | 58,013 |
| Within 30 days | 1,602 | 52,663 |
| Later than 30 days | 2,355 | 110,262 |

- Of the £332,055 in the first row, about £245,650 is just two orders (customers 16446 and 12346). This is my own calculation.
- The 24 hour rule covers the first two rows: 1,090 lines and about £367k of purchases (my addition). Bills are not added up, because one bill can appear in more than one row.
- After the first day, cancellations are spread over days and months, which looks like normal returns. There is no sharp break in the data, so 24 hours is a judgment call.

**Version 2 segments**

| Segment | Customers | % of customers | Money (£) | % of money | Avg days since last bill | Avg orders | Avg spend (£) |
|---|---|---|---|---|---|---|---|
| Champions | 1,245 | 21.3% | 11,450,508 | 68.4% | 20 | 17.3 | 9,197 |
| Loyal | 1,330 | 22.7% | 2,614,007 | 15.6% | 71 | 5.7 | 1,965 |
| At Risk | 709 | 12.1% | 1,435,996 | 8.6% | 359 | 5.5 | 2,025 |
| Lost | 1,636 | 28.0% | 697,154 | 4.2% | 454 | 1.3 | 426 |
| New / Recent | 505 | 8.6% | 272,591 | 1.6% | 28 | 1.5 | 540 |
| Needs Attention | 426 | 7.3% | 269,602 | 1.6% | 107 | 1.4 | 633 |

**What changed compared with version 1**
- **The main story is the same.** Champions are still 21.3% of customers and now bring 68.4% of the money (67.5% before). Champions and Loyal together are 44.0% of customers and bring 84.0% of the money (my addition).
- **The biggest change is New / Recent.** Its money fell from £441,697 to £272,591 and its average spend from £873 to £540. The reason: customer 16446 moved to Lost, because its £168k order was cancelled.
- **Customer 16446** now has Recency 206 days, 1 order, £2.90, segment Lost. **Customer 12346** has Recency 530 days, 2 orders, £169.36, segment Lost.
- **Top 10 customers:** customer 16446 left the list and customer 15061 joined. The top 10 bring about £2.69M, which is about 16.1% of the money. The biggest customer (18102) brings about 3.5%. These two figures are my own calculation.
- Smaller changes: customer 18102 went from £580,987 to £579,705, and customer 14156 from 145 to 144 orders.

**Use the version 2 numbers in the README.** The first version is kept in `sql/02_rfm.sql` for comparison.

---

## 11. Cohort retention results (Confirmed, from `sql/04_cohort.sql`)

**How it was defined**
- **Cohort** = the month of a customer's first purchase. **Active** = at least one purchase in that month. **Retention %** = customers active in month N divided by customers in the cohort.
- Only complete months are used (Dec 2009 to Nov 2011). Dec 2011 has only 9 days.
- The Dec 2009 cohort is shown but left out of the average, because the data starts then and it also holds old customers.
- Same cleaned purchases as RFM version 2 (`clean_sales_v2`).

**Sanity check:** 5,823 customers have a purchase, and the cohort sizes add up to 5,823. RFM version 2 had 5,851 customers. The 28 missing are probably customers whose only purchases were in Dec 2011 (my reading, not checked).

**Retention by cohort** (% of the cohort active N months after the first purchase, "-" = not enough time yet)

| Cohort | Customers | m1 | m2 | m3 | m6 | m9 | m12 |
|---|---|---|---|---|---|---|---|
| 2009-12 | 951 | 34.9 | 33.3 | 42.5 | 37.6 | 36.2 | 37.6 |
| 2010-01 | 368 | 21.2 | 31.8 | 31.5 | 26.9 | 32.6 | 22.8 |
| 2010-02 | 374 | 23.5 | 22.7 | 29.4 | 19.3 | 27.8 | 15.0 |
| 2010-03 | 441 | 19.0 | 23.1 | 24.3 | 24.7 | 10.9 | 20.0 |
| 2010-04 | 294 | 19.0 | 19.0 | 16.0 | 27.6 | 10.9 | 14.3 |
| 2010-05 | 253 | 15.8 | 17.0 | 17.8 | 21.3 | 8.3 | 15.4 |
| 2010-06 | 267 | 17.6 | 18.7 | 20.6 | 12.7 | 11.2 | 15.0 |
| 2010-07 | 186 | 15.6 | 18.3 | 29.6 | 11.3 | 11.3 | 12.9 |
| 2010-08 | 163 | 19.6 | 28.8 | 32.5 | 9.8 | 12.9 | 14.7 |
| 2010-09 | 238 | 23.1 | 23.5 | 13.0 | 13.9 | 13.0 | 22.7 |
| 2010-10 | 374 | 25.7 | 14.7 | 12.6 | 13.1 | 9.4 | 19.3 |
| 2010-11 | 327 | 17.4 | 9.5 | 9.5 | 13.1 | 9.5 | 25.1 |
| 2010-12 | 76 | 9.2 | 5.3 | 9.2 | 5.3 | 2.6 | - |
| 2011-01 | 72 | 15.3 | 22.2 | 19.4 | 15.3 | 20.8 | - |
| 2011-02 | 126 | 15.9 | 16.7 | 19.0 | 15.9 | 18.3 | - |
| 2011-03 | 179 | 17.9 | 21.8 | 20.1 | 20.7 | - | - |
| 2011-04 | 106 | 24.5 | 19.8 | 19.8 | 17.9 | - | - |
| 2011-05 | 111 | 23.4 | 24.3 | 16.2 | 26.1 | - | - |
| 2011-06 | 108 | 23.1 | 21.3 | 26.9 | - | - | - |
| 2011-07 | 101 | 20.8 | 29.7 | 27.7 | - | - | - |
| 2011-08 | 107 | 26.2 | 29.9 | 26.2 | - | - | - |
| 2011-09 | 188 | 27.1 | 37.8 | - | - | - | - |
| 2011-10 | 222 | 31.5 | - | - | - | - | - |
| 2011-11 | 191 | - | - | - | - | - | - |

**Average retention, all cohorts except Dec 2009**

| Month | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Retention % | 100 | 20.9 | 21.5 | 21.1 | 19.4 | 18.5 | 18.5 | 18.6 | 16.4 | 15.0 | 13.4 | 14.0 | 18.4 |

**What I see**
1. **About 1 in 5 new customers buys again the next month** (20.9%). It stays near 21% for months 2 and 3, is 18.5% at month 6, and is lowest at month 10 (13.4%).
2. **Customers seem to come back in the same season the next year.** The Nov 2010 cohort has 25.1% at month 12 (Nov 2011), but only about 9.5% in several months before that. The Oct 2010 cohort has 19.3% at month 12 against 9.4% at month 9. The Sep 2010 cohort has 22.7% against 13.0%. This fits the Sep to Nov sales peak (my interpretation).
3. **Late 2011 cohorts return well.** Sep 2011 has 37.8% at month 2 (Nov 2011, the peak month) and Oct 2011 has 31.5% at month 1 (Nov 2011). Probably the season again (my interpretation).
4. **The Dec 2010 cohort is small (76 customers) and weak** (9.2% at month 1, 2.6% at month 9). I do not know why.
5. **The Dec 2009 cohort has 951 customers and 33% to 43% retention.** This is higher than every other cohort, as expected, because it contains old customers.
6. **Fewer new customers in 2011.** Jan to Nov 2010 had 3,285 new customers (about 299 a month) and Jan to Nov 2011 had 1,511 (about 137 a month). These sums are my own. This may be partly an artifact: because the data starts in Dec 2009, some customers counted as "new" in 2010 were really old customers. Not confirmed.

**Cautions**
- Each month number in the average covers different cohorts. Month 12 covers only the Jan to Nov 2010 cohorts, while month 1 covers almost all of them. So comparing month 1 with month 12 mixes cohorts. `sql/05_checks_and_pareto.sql` repeats the average with the same 11 cohorts for every month.
- Small cohorts (under about 100 customers) move up and down a lot.
- "Active" means bought in that month. A customer can skip a month and come back later.

### Same-cohort check (Confirmed, from `sql/05_checks_and_pareto.sql`, part A)

Only the Jan to Nov 2010 cohorts (3,285 customers), which all have 12 months of data, so every month number covers the same customers.

| Month | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Retention % | 100 | 20.2 | 20.6 | 21.2 | 18.7 | 18.6 | 18.6 | 18.8 | 16.4 | 15.0 | 13.2 | 13.9 | 18.4 |

- **The picture did not change.** About 20% in months 1 to 3, about 18.6% in months 4 to 7, lowest at month 10 (13.2%), and up again at month 12 (18.4%, which is 605 active customers against 455 at month 11).
- So mixing different cohorts in the first average (Section 11) did not distort the story.
- Month 12 falls in a different calendar month for each cohort (Jan to Nov 2011). A yearly buying pattern is one possible reason for the rise (my interpretation).

---

## 12. Pareto of customer spend (Confirmed, from `sql/05_checks_and_pareto.sql`, part B)

The 5,851 scored customers are ranked by spend (RFM version 2) and split into 10 equal groups. Decile 1 = the top 10% of customers.

| Decile | Customers | Money (£) | % of money | Cumulative % |
|---|---|---|---|---|
| 1 (top 10%) | 586 | 10,601,558 | 63.3% | 63.3% |
| 2 | 585 | 2,256,738 | 13.5% | 76.8% |
| 3 | 585 | 1,325,003 | 7.9% | 84.7% |
| 4 | 585 | 860,643 | 5.1% | 89.9% |
| 5 | 585 | 596,406 | 3.6% | 93.4% |
| 6 | 585 | 422,473 | 2.5% | 96.0% |
| 7 | 585 | 289,049 | 1.7% | 97.7% |
| 8 | 585 | 199,204 | 1.2% | 98.9% |
| 9 | 585 | 126,779 | 0.8% | 99.6% |
| 10 (bottom 10%) | 585 | 62,004 | 0.4% | 100.0% |

The deciles add up to £16.74M, the same total as RFM version 2.

**What I see**
1. **The top 10% of customers bring 63.3% of the money.** The top 20% bring 76.8% and the top 30% bring 84.7%. The bottom 50% of customers bring only 6.6% (100 minus 93.4, my addition).
2. **Average spend per customer** is about £18,090 in the top decile and about £106 in the bottom decile (my own calculation).
3. **Even the top decile is very uneven.** The 10 biggest customers (£2.69M) are about 25% of the money of the whole top decile (my calculation).
4. **Champions and "top 20% by spend" are different groups.** Champions (21.3% of customers, 68.4% of money) are chosen using recency and frequency as well as spend, so the numbers differ from the top 20% by spend (20% of customers, 76.8% of money).

**Limits:** money is gross (returns after 24 hours are not taken off), only customers with an ID are included (about 85% of the money), and many customers are probably wholesalers (my assumption).
