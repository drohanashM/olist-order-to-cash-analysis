# Order-to-Cash Performance Analysis: Olist E-commerce

**Business question:** Where is the business losing revenue or customer satisfaction, and what should management do about it?

This project follows every order from sale to delivery to payment to customer review, using only real data from the public Olist marketplace dataset (99,441 orders, Sep-2016 to Oct-2018).

**Short answer:** late delivery is the biggest leak we can control. It affects 6.8% of delivered orders, but those orders score about 2 stars lower.

## Dataset

Olist Brazilian E-Commerce Public Dataset (Kaggle): https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

Nine CSV files: orders, order items, payments, reviews, customers, products, sellers, category translation, geolocation. Amounts are in Brazilian reais (R$).

## What is in this repo

| File | What it is |
|---|---|
| `01_data_quality_report.md` | Row counts, nulls, duplicates, issues fixed, assumptions |
| `02_olist_sql_queries.sql` | 8 commented SQLite queries (joins, CTEs, window functions) |
| `03_olist_sql_analysis_notebook.ipynb` | Jupyter notebook: loads the CSVs into SQLite, runs all 8 queries and shows the results |
| `04_sql_query_results.md` | The actual output of each query |
| `05_olist_excel_dashboard.xlsx` | Excel dashboard: KPI cards, 4 native charts, formulas, "How to read this" note |
| `06_olist_recommendations_deck.pptx` | 6-slide recommendation deck |

## How to reproduce

1. Download the dataset from the Kaggle link and unzip the CSVs into a folder named `data/`.
2. Put `03_olist_sql_analysis_notebook.ipynb` and `02_olist_sql_queries.sql` in the folder that contains `data/`.
3. Install the libraries: `pip install pandas jupyter`.
4. Run `jupyter notebook`, open `03_olist_sql_analysis_notebook.ipynb` and choose *Run All*. The notebook builds `olist.db` (SQLite), runs the 8 queries from `02_olist_sql_queries`, shows each result and saves them as `Q1_result.csv` to `Q8_result.csv` in the folder named `results/`.
5. Or open `olist.db` in any SQLite tool and run the queries in the SQL file one by one.

## Definitions

- **Revenue:** sum of item prices (freight excluded) on orders that are not canceled or unavailable.
- **Late delivery:** delivered on a later calendar day than the estimated delivery date.
- **Customer:** identified by `customer_unique_id` (the `customer_id` changes with every order).
- **Review score:** latest review per order.

## Key findings

1. **Size of the business:** R$13,494,400.74 revenue from 98,199 orders; average order value R$137.42 (item prices only). Average review score 4.09.
2. **Growth:** monthly revenue grew from R$120,098 in Jan-2017 to a peak of R$1,003,862 in Nov-2017, then stayed between R$838k and R$994k a month in 2018 (Jan to Aug).
3. **Category mix:** the top 10 categories give 62.4% of revenue. Health & beauty (R$1.26M, 9.3%), watches & gifts (R$1.20M, 8.9%) and bed, bath & table (R$1.04M, 7.7%) lead.
4. **Delivery:** 93.2% of delivered orders arrive on time. Orders arrive on average 12.6 days after purchase against 23.7 days promised.
5. **Late deliveries hurt satisfaction:** on-time orders average 4.29 stars; late 1-3 days 3.29; late 4-7 days 2.10; late over 7 days 1.70. Late orders are 6.7% of reviewed orders but 32.5% of all 1-2 star reviews.
6. **Where:** AL (21.4% late), MA (17.4%), SE (15.2%), PI (13.9%) and CE (13.8%) are worst, against 4.5% in São Paulo and 6.8% overall.
7. **When:** Nov-2017, Feb-2018 and Mar-2018 were 15.1% late versus 4.5% in the other months.
8. **Sellers:** among sellers with 50+ orders, the 15 weakest have 13.7% to 28.2% late deliveries. Cancellations are rare, so lateness is the real seller problem.
9. **Payments:** credit card is 75.2% of orders and 78.3% of money paid; boleto is 19.5% of orders.
10. **Customers:** 97.0% of customers bought only once and give 94.4% of revenue. Repeat customers (3.0%) bring R$259.95 each against R$138.38.

## Recommendations (see the deck)

1. Review carriers and promise dates in AL, MA, SE, PI, CE.
2. Put the 15 weakest sellers on a watch list.
3. Plan extra delivery capacity before peak months.
4. Give first-time buyers a reason to return.

Impact numbers in the deck are simple what-ifs using this dataset's own averages, not forecasts.

## Limits

- No cost or margin data, so profit cannot be calculated.
- The data shows where and when orders are late, not why.
- There is no invoice table; payments are the closest match to billing.
- A strong link between late delivery and low review scores is shown; it does not prove cause.

## Tools

Python (pandas, sqlite3), Jupyter, SQLite, Excel (openpyxl, native charts and formulas), PowerPoint.
