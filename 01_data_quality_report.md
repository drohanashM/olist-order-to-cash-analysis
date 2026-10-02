# Data check

Dataset: Olist Brazilian E-Commerce (9 CSV files). Loaded into SQLite and checked with SQL and pandas.

## 1. Table sizes, nulls and duplicates

| Table | Rows | Columns with missing values (count) | Full duplicate rows |
|---|---|---|---|
| orders | 99,441 | order_approved_at (160), order_delivered_carrier_date (1,783), order_delivered_customer_date (2,965) | 0 |
| order_items | 112,650 | none | 0 |
| order_payments | 103,886 | none | 0 |
| order_reviews | 99,224 | review_comment_title (87,656), review_comment_message (58,247) | 0 |
| customers | 99,441 | none | 0 |
| products | 32,951 | product_category_name and 3 text/photo fields (610 each), weight and 3 size fields (2 each) | 0 |
| sellers | 3,095 | none | 0 |
| category_translation | 71 | none | 0 |
| geolocation | 1,000,163 | none | 261,831 (not used in this analysis) |

Missing delivery dates are mostly normal: they belong to orders that were canceled, unavailable or still on the way (see issue 3).

## 2. Keys and links between tables

- order_id is unique in orders (99,441). Every order links to a customer. Every order line links to a valid order, product and seller (0 orphans).
- customer_id is unique per order (99,441) but only 96,096 distinct customer_unique_id exist, so the same real person can appear under several customer_ids.
- 775 orders have no order lines (603 unavailable, 164 canceled, 5 created, 2 invoiced, 1 shipped).
- 1 order has no payment row; 768 orders have no review (646 of them delivered).
- Order period: 4 Sep 2016 to 17 Oct 2018. Only a handful of orders exist in 2016 (4 + 324 + 1) and in Sep-Oct 2018 (16 + 4); there are none in Nov-2016.

## 3. Data-quality issues found and what I did

| # | Issue (count) | Fix applied |
|---|---|---|
| 1 | 547 orders have more than one review (99,224 reviews for 98,673 orders) | Kept the latest review per order (ROW_NUMBER by answer timestamp) so no order is counted twice |
| 2 | customer_id changes with every order | Used customer_unique_id to count real customers (repeat vs one-time) |
| 3 | 1,234 orders are canceled (625) or unavailable (609); 1,722 are stuck in shipped, invoiced or processing | Excluded canceled and unavailable orders from revenue and order counts; delivery metrics use delivered orders only |
| 4 | 8 delivered orders have no customer delivery date; 6 non-delivered orders have one | Delivery metrics use only status = delivered with a delivery date (96,470 orders) |
| 5 | 23 orders show customer delivery earlier than carrier pickup | Kept (only the customer date vs estimate is used); flagged as a data oddity |
| 6 | 610 products have no category (1,603 order lines, R$179,535.28 of item prices) | Shown as "unknown" if they ever rank; they are not in the top 10 |
| 7 | 13 products have categories missing from the English translation file (pc_gamer, portateis_cozinha_e_preparadores_de_alimentos) | Fell back to the Portuguese name |
| 8 | Dates are stored as text | Converted with SQLite date functions (strftime, date, julianday) |
| 9 | 3 payments typed "not_defined" (value 0); 9 zero-value payments; 2 payments with 0 instalments | Kept; negligible effect |
| 10 | Payments total R$16,008,872.12 vs item prices plus freight R$15,843,553.24; 249 orders differ by more than R$1 | Revenue is based on item prices, not payments. Payments are used only for payment mix and order value in Q7 |
| 11 | Geolocation has 261,831 duplicate rows | Not needed, so left unused |

## 4. Assumptions (one line each)

1. Revenue = sum of item prices, freight excluded, on orders not canceled or unavailable. Amounts are R$ (the CSVs do not state the currency; this is from the dataset description).
2. Late = delivered on a later calendar day than the estimated delivery date. (If measured to the exact timestamp against midnight of the estimated day, 7,826 orders, 8.1%, would be late instead of 6,534, 6.8%.)
3. Delivery analysis uses delivered orders with a delivery date only.
4. One review per order (the latest).
5. A real customer = customer_unique_id.
6. Seller rates need at least 50 orders. An order with several sellers counts once for each seller.
7. There is no invoice table; payments are used as the closest match to billing and cash.
8. No cost or margin data exists, so profit cannot be calculated.
