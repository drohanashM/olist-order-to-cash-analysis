# Delivery Performance, Customer Retention & Forecasting Analytics: Olist E-commerce

**Business question:** Where is the business losing revenue or customer satisfaction, and what should management do about it?

This project follows every order from sale to delivery to payment to customer review, using only real data from the public Olist marketplace dataset (99,441 orders, Sep-2016 to Oct-2018). It has two parts:

- **Part 1: Order-to-cash analysis** (SQL, Excel, PowerPoint): what is happening and where.
- **Part 2: Statistics, segmentation, prediction and forecasting** (Python): is the pattern real, who is affected, can we predict it, and what comes next.

**Short answer:** late delivery is the biggest leak we can control. It affects 6.8% of delivered orders, but those orders score about 2 stars lower, and customers whose first order arrives late are less likely to buy again.

**Live dashboard (Tableau Public):** [LINK](https://public.tableau.com/views/OlistDeliveryPerformanceandRetention/Dashboard1?:language=en-US&publish=yes&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)

## Dataset

Olist Brazilian E-Commerce Public Dataset (Kaggle): https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

Nine CSV files: orders, order items, payments, reviews, customers, products, sellers, category translation, geolocation. Amounts are in Brazilian reais (R$). The data is not included in this repo; download it from the link above.

## What is in this repo

| File | What it is |
|---|---|
| `01_data_quality_report.md` | Row counts, nulls, duplicates, issues fixed, assumptions |
| `02_olist_sql_queries.sql` | 8 commented SQLite queries (joins, CTEs, window functions) |
| `03_olist_sql_analysis_notebook.ipynb` | Jupyter notebook: loads the CSVs into SQLite, runs all 8 queries and shows the results |
| `04_sql_query_results.md` | The actual output of each query |
| `05_olist_excel_dashboard.xlsx` | Excel dashboard: KPI cards, 4 native charts, formulas, "How to read this" note |
| `06_olist_recommendations_deck.pptx` | 6-slide recommendation deck |
| `07_stats_ml_forecasting_notebook.ipynb` | **Part 2:** hypothesis tests, regression, clustering, classification, ARIMA, survival analysis |
| `figures/` | Charts saved by notebook 07 |
| `tableau_exports/` | CSVs that feed the Tableau Public dashboard |

## How to reproduce

1. Download the dataset from the Kaggle link and unzip the CSVs into a folder named `data/`.
2. Put the notebooks and `02_olist_sql_queries.sql` in the folder that contains `data/`.
3. Install the libraries: `pip install pandas numpy scipy scikit-learn matplotlib statsmodels jupyter`.
4. Run `03_olist_sql_analysis_notebook.ipynb` first (*Run All*). It builds `olist.db` (SQLite), runs the 8 queries and saves the results in `results/`.
5. Then run `07_stats_ml_forecasting_notebook.ipynb`. It reads `olist.db`, saves charts to `figures/` and the Tableau files to `tableau_exports/`.
6. Or open `olist.db` in any SQLite tool and run the queries in the SQL file one by one.

## Definitions

- **Revenue:** sum of item prices (freight excluded) on orders that are not canceled or unavailable.
- **Late delivery:** delivered on a later calendar day than the estimated delivery date.
- **Customer:** identified by `customer_unique_id` (the `customer_id` changes with every order).
- **Review score:** latest review per order.
- **Repeat purchase (survival analysis):** a second order on a later calendar day, so split carts on the same day do not count.

# Part 1: Order-to-cash analysis

## Key findings

1. **Size of the business:** R\$13,494,400.74 revenue from 98,199 orders; average order value R\$137.42 (item prices only). Average review score 4.09.
2. **Growth:** monthly revenue grew from R\$120,098 in Jan-2017 to a peak of R\$1,003,862 in Nov-2017, then stayed between R\$838k and R\$994k a month in 2018 (Jan to Aug).
3. **Category mix:** the top 10 categories give 62.4% of revenue. Health & beauty (R\$1.26M, 9.3%), watches & gifts (R\$1.20M, 8.9%) and bed, bath & table (R\$1.04M, 7.7%) lead.
4. **Delivery:** 93.2% of delivered orders arrive on time. Orders arrive on average 12.6 days after purchase against 23.7 days promised.
5. **Late deliveries hurt satisfaction:** on-time orders average 4.29 stars; late 1-3 days 3.29; late 4-7 days 2.10; late over 7 days 1.70. Late orders are 6.7% of reviewed orders but 32.5% of all 1-2 star reviews.
6. **Where:** AL (21.4% late), MA (17.4%), SE (15.2%), PI (13.9%) and CE (13.8%) are worst, against 4.5% in São Paulo and 6.8% overall.
7. **When:** Nov-2017, Feb-2018 and Mar-2018 were 15.1% late versus 4.5% in the other months.
8. **Sellers:** among sellers with 50+ orders, the 15 weakest have 13.7% to 28.2% late deliveries. Cancellations are rare, so lateness is the real seller problem.
9. **Payments:** credit card is 75.2% of orders and 78.3% of money paid; boleto is 19.5% of orders.
10. **Customers:** 97.0% of customers bought only once and give 94.4% of revenue. Repeat customers (3.0%) bring R\$259.95 each against R\$138.38.


# Part 2: Statistics, segmentation, prediction and forecasting

Notebook `07_stats_ml_forecasting_notebook.ipynb` tests whether the Part 1 findings hold up statistically and extends them.

## 1. Is the lateness effect real? (hypothesis tests, bootstrap, regression)

- Late orders average **2.27** stars against **4.29** for on-time orders (96K delivered orders; 95.8K with a review).
- Mann-Whitney U test: p < 0.001, Cliff's delta -0.64 (a large effect).
- Bootstrapped 95% CI (2,000 resamples) for the mean difference: **-2.02 stars [-2.06, -1.98]**.
- OLS regression of review score on lateness, controlling for price, freight ratio, promised delivery time, items per order and customer state: being late costs **-1.87 stars** (bootstrap 95% CI [-1.93, -1.81]), plus **-0.015 stars per extra day late** (R² = 0.18).
- The effect survives the controls. It is still observational, so it shows a strong association, not proof of cause.

## 2. Customer segments (RFM + K-Means)

97% of customers buy once, so frequency barely varies. The clustering uses recency, spend, average review score and a repeat flag. K = 4 was chosen from the elbow and silhouette plots and because the segments can be explained to a business reader (the silhouette score alone favours k = 2, which only separates repeat buyers from everyone else).

| Segment | Customers | Share of customers | Share of revenue |
|---|---|---|---|
| Recent satisfied one-timers | 43,119 | 45.4% | 41.7% |
| Lapsed satisfied one-timers | 32,505 | 34.2% | 33.1% |
| Unhappy one-time buyers (avg score 1.63) | 16,472 | 17.3% | 19.7% |
| Repeat buyers | 2,887 | 3.0% | 5.6% |

The unhappy segment is a sixth of the customer base and about a fifth of revenue.

## 3. Predicting late delivery (logistic regression, decision tree, gradient boosting)

Goal: flag orders likely to be late at checkout, before delivery. Only information known at purchase time is used (price, freight, weight, items, sellers, promised days, customer and seller state).

| Model | AUC |
|---|---|
| Logistic regression | 0.708 |
| Decision tree (depth 4) | 0.664 |
| Gradient boosting | 0.719 |

- With gradient boosting, flagging the riskiest 10% of orders catches **28.8% of all late orders**; 19.5% of the flagged orders are late against a 6.8% base rate (about 2.9x).
- Strongest driver by permutation importance: **promised delivery days**, then customer state (SP, MG, RJ) and freight.
- Limit: a random train/test split was used, and lateness clusters in peak months, so performance on future months is likely lower.

## 4. Revenue forecast (ARIMA)

Only Jan-2017 to Aug-2018 (20 months) is usable. The last 4 months were held out and ARIMA was compared with a naive "last value" forecast.

- AIC picked ARIMA(2,1,1) on the training months.
- **ARIMA MAPE 28.2% against 11.3% for the naive baseline: ARIMA lost.** It carried the strong 2017 growth, including the Black Friday jump, into a flatter 2018.
- Conclusion: 20 months is too short to model trend and seasonality. The Sep to Nov 2018 forecast (about R$830k to R$850k a month, with wide 95% intervals) is shown as indicative only. The value here is the process (train/test split, baseline comparison, honest result), not the forecast.

## 5. Time to second purchase (Kaplan-Meier survival analysis)

Event = second purchase on a later day; customers who never return are censored. Customers are split by whether their first order arrived late.

- Share who bought again within 180 days: **1.96%** (first order on time) against **1.62%** (first order late).
- Log-rank test: chi-square = 6.42, **p = 0.011**.
- The gap is statistically significant but small in absolute terms, because almost nobody buys again.

## 6. Dashboard

A Tableau Public dashboard combines: late % by state (map), review score by lateness, customer segments, the repeat-purchase curve, and monthly revenue with the ARIMA forecast. The input files are in `tableau_exports/`.

[Tableau Public Dashboard](https://public.tableau.com/views/OlistDeliveryPerformanceandRetention/Dashboard1?:language=en-US&publish=yes&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)

## Recommendations (see the deck)

1. Review carriers and promise dates in AL, MA, SE, PI, CE.
2. Put the 15 weakest sellers on a watch list.
3. Plan extra delivery capacity before peak months.
4. Give first-time buyers a reason to return.
5. Use the late-delivery risk model to flag high-risk orders at checkout, so the promise date can be widened or the order checked early. Start by testing it on a small share of orders.

Impact numbers in the deck are simple what-ifs using this dataset's own averages, not forecasts.

## Limits

- No cost or margin data, so profit cannot be calculated.
- The data shows where and when orders are late, not why.
- There is no invoice table; payments are the closest match to billing.
- A strong link between late delivery and low review scores is shown; it does not prove cause.
- Repeat purchases are rare (about 3%), so retention results rest on small counts.
- The forecast uses 20 monthly points and did not beat a naive baseline.

## Tools

Python (pandas, NumPy, SciPy, scikit-learn, statsmodels, matplotlib), Jupyter, SQLite, Excel, PowerPoint, Tableau Public.
