-- =====================================================================
-- OLIST ORDER-TO-CASH ANALYSIS  (SQLite)
-- Tables expected (loaded from the Olist CSVs, same names as below):
--   orders, order_items, order_payments, order_reviews,
--   customers, products, sellers, category_translation
--
-- DEFINITIONS USED IN EVERY QUERY (change here if you prefer another rule)
--   Revenue        = sum of item price (freight excluded) on orders that are
--                    NOT 'canceled' and NOT 'unavailable'.
--   Delivered      = order_status = 'delivered' AND a customer delivery date exists.
--   Late delivery  = delivery DATE is after the ESTIMATED delivery DATE.
--   Order month    = month of order_purchase_timestamp.
-- SAP SD mapping: orders = sales order (VA01), order_items = order lines,
--   delivery dates = delivery (VL01N / goods issue), payments = billing & payment.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Q1. MONTHLY REVENUE AND ORDER TREND  (CTE + window functions)
-- Business question: is the business growing, and how fast month on month?
-- Note: the data has no orders in Nov-2016 and only a handful in 2016 and Sep-2018,
-- so ignore the growth % on those tiny months; the real trend is Jan-2017 to Aug-2018.
-- ---------------------------------------------------------------------
WITH valid_orders AS (
    SELECT order_id, strftime('%Y-%m', order_purchase_timestamp) AS order_month
    FROM orders
    WHERE order_status NOT IN ('canceled', 'unavailable')
),
monthly AS (
    SELECT v.order_month,
           COUNT(DISTINCT v.order_id)          AS orders,
           ROUND(SUM(oi.price), 2)             AS revenue
    FROM valid_orders v
    JOIN order_items oi ON oi.order_id = v.order_id
    GROUP BY v.order_month
)
SELECT order_month,
       orders,
       revenue,
       ROUND(revenue * 1.0 / orders, 2)                                   AS avg_order_value,
       LAG(revenue) OVER (ORDER BY order_month)                           AS prev_month_revenue,
       -- growth is shown only when the previous month had 100+ orders
       -- (2016 and Jan-2017 are too small to give a meaningful % change)
       CASE WHEN LAG(orders) OVER (ORDER BY order_month) >= 100
            THEN ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY order_month))
                       / LAG(revenue) OVER (ORDER BY order_month), 1) END AS mom_growth_pct,
       ROUND(SUM(revenue) OVER (ORDER BY order_month), 2)                 AS cumulative_revenue
FROM monthly
ORDER BY order_month;


-- ---------------------------------------------------------------------
-- Q2. TOP 10 PRODUCT CATEGORIES BY REVENUE (English names)
-- Business question: which product groups earn the money?
-- Uses RANK() and share of total revenue.
-- ---------------------------------------------------------------------
WITH cat_rev AS (
    SELECT COALESCE(t.product_category_name_english,
                    p.product_category_name,
                    'unknown')                       AS category,
           COUNT(DISTINCT oi.order_id)               AS orders,
           COUNT(*)                                  AS items_sold,
           ROUND(SUM(oi.price), 2)                   AS revenue
    FROM order_items oi
    JOIN orders o                    ON o.order_id = oi.order_id
    JOIN products p                  ON p.product_id = oi.product_id
    LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY 1
),
ranked AS (
    SELECT *,
           RANK() OVER (ORDER BY revenue DESC)                          AS revenue_rank,
           ROUND(100.0 * revenue / SUM(revenue) OVER (), 1)             AS pct_of_total_revenue
    FROM cat_rev
)
SELECT revenue_rank, category, orders, items_sold, revenue, pct_of_total_revenue,
       ROUND(SUM(pct_of_total_revenue) OVER (ORDER BY revenue_rank), 1) AS cumulative_pct
FROM ranked
WHERE revenue_rank <= 10
ORDER BY revenue_rank;


-- ---------------------------------------------------------------------
-- Q3. AVERAGE DELIVERY TIME vs ESTIMATED DELIVERY, BY CUSTOMER STATE
-- Business question: how long do customers wait, and how does that compare
-- with the date we promised?  (delivered orders only)
-- ---------------------------------------------------------------------
WITH delivered AS (
    SELECT c.customer_state,
           julianday(o.order_delivered_customer_date) - julianday(o.order_purchase_timestamp)      AS actual_days,
           julianday(o.order_estimated_delivery_date) - julianday(o.order_purchase_timestamp)      AS promised_days
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
)
SELECT customer_state,
       COUNT(*)                                        AS delivered_orders,
       ROUND(AVG(actual_days), 1)                      AS avg_actual_days,
       ROUND(AVG(promised_days), 1)                    AS avg_promised_days,
       ROUND(AVG(promised_days - actual_days), 1)      AS avg_days_early_minus_late,
       RANK() OVER (ORDER BY AVG(actual_days) DESC)    AS slowest_rank
FROM delivered
GROUP BY customer_state
ORDER BY avg_actual_days DESC;


-- ---------------------------------------------------------------------
-- Q4. SHARE OF LATE DELIVERIES BY STATE
-- Late = delivery date later than estimated date.
-- Also shows how many days late the late orders are on average.
-- ---------------------------------------------------------------------
WITH delivered AS (
    SELECT c.customer_state,
           CASE WHEN date(o.order_delivered_customer_date) > date(o.order_estimated_delivery_date)
                THEN 1 ELSE 0 END AS is_late,
           julianday(date(o.order_delivered_customer_date))
             - julianday(date(o.order_estimated_delivery_date)) AS days_vs_estimate
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
)
SELECT customer_state,
       COUNT(*)                                                   AS delivered_orders,
       SUM(is_late)                                               AS late_orders,
       ROUND(100.0 * SUM(is_late) / COUNT(*), 1)                  AS late_pct,
       ROUND(AVG(CASE WHEN is_late = 1 THEN days_vs_estimate END), 1) AS avg_days_late_when_late,
       RANK() OVER (ORDER BY 1.0 * SUM(is_late) / COUNT(*) DESC)  AS worst_rank
FROM delivered
GROUP BY customer_state
ORDER BY late_pct DESC;


-- ---------------------------------------------------------------------
-- Q5. EFFECT OF LATE DELIVERY ON REVIEW SCORE
-- One review per order is kept (the most recent) so no order is counted twice.
-- Buckets: on time / 1-3 days late / 4-7 days late / more than 7 days late.
-- ---------------------------------------------------------------------
WITH latest_review AS (
    SELECT order_id, review_score
    FROM (
        SELECT order_id, review_score,
               ROW_NUMBER() OVER (PARTITION BY order_id
                                  ORDER BY review_answer_timestamp DESC, review_id) AS rn
        FROM order_reviews
    )
    WHERE rn = 1
),
delivered AS (
    SELECT o.order_id,
           julianday(date(o.order_delivered_customer_date))
             - julianday(date(o.order_estimated_delivery_date)) AS days_late
    FROM orders o
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
),
bucketed AS (
    SELECT d.order_id, r.review_score,
           CASE WHEN d.days_late <= 0 THEN '1. On time or early'
                WHEN d.days_late <= 3 THEN '2. Late 1-3 days'
                WHEN d.days_late <= 7 THEN '3. Late 4-7 days'
                ELSE                       '4. Late more than 7 days' END AS delivery_bucket
    FROM delivered d
    JOIN latest_review r ON r.order_id = d.order_id
)
SELECT delivery_bucket,
       COUNT(*)                                              AS reviewed_orders,
       ROUND(AVG(review_score), 2)                           AS avg_review_score,
       ROUND(100.0 * SUM(review_score <= 2) / COUNT(*), 1)   AS pct_bad_reviews_1_2_stars,
       ROUND(100.0 * SUM(review_score = 5)  / COUNT(*), 1)   AS pct_five_star
FROM bucketed
GROUP BY delivery_bucket
ORDER BY delivery_bucket;


-- ---------------------------------------------------------------------
-- Q6. SELLERS WITH THE HIGHEST LATE-DELIVERY / CANCELLATION RATES
-- Minimum threshold: sellers with at least 50 orders.
-- "Problem order" = delivered late OR canceled. (An order with several sellers
-- counts once for each seller involved.)
-- ---------------------------------------------------------------------
WITH seller_orders AS (
    SELECT DISTINCT oi.seller_id, o.order_id, o.order_status,
           CASE WHEN o.order_status = 'delivered'
                 AND o.order_delivered_customer_date IS NOT NULL
                 AND date(o.order_delivered_customer_date) > date(o.order_estimated_delivery_date)
                THEN 1 ELSE 0 END AS is_late,
           CASE WHEN o.order_status = 'canceled' THEN 1 ELSE 0 END AS is_canceled
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
),
seller_stats AS (
    SELECT seller_id,
           COUNT(*)          AS orders,
           SUM(is_late)      AS late_orders,
           SUM(is_canceled)  AS canceled_orders,
           SUM(is_late + is_canceled) AS problem_orders
    FROM seller_orders
    GROUP BY seller_id
    HAVING COUNT(*) >= 50
)
SELECT RANK() OVER (ORDER BY 1.0 * problem_orders / orders DESC) AS problem_rank,
       ss.seller_id,
       s.seller_state,
       orders, late_orders, canceled_orders,
       ROUND(100.0 * late_orders / orders, 1)     AS late_pct,
       ROUND(100.0 * canceled_orders / orders, 1) AS canceled_pct,
       ROUND(100.0 * problem_orders / orders, 1)  AS problem_pct
FROM seller_stats ss
JOIN sellers s ON s.seller_id = ss.seller_id
ORDER BY problem_pct DESC, orders DESC
LIMIT 15;


-- ---------------------------------------------------------------------
-- Q7. PAYMENT METHOD MIX AND AVERAGE ORDER VALUE
-- Order value = total payments received for the order (all instalments/vouchers).
-- Orders paid with more than one method are counted under each method used,
-- so the "orders" column can add up to more than the number of orders.
-- ---------------------------------------------------------------------
WITH pay AS (
    SELECT order_id, payment_type,
           SUM(payment_value)         AS paid_by_method,
           MAX(payment_installments)  AS installments
    FROM order_payments
    GROUP BY order_id, payment_type
),
order_total AS (
    SELECT order_id, SUM(payment_value) AS order_paid
    FROM order_payments
    GROUP BY order_id
)
SELECT p.payment_type,
       COUNT(*)                                              AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)    AS pct_of_orders,
       ROUND(SUM(p.paid_by_method), 2)                       AS amount_paid,
       ROUND(100.0 * SUM(p.paid_by_method)
             / SUM(SUM(p.paid_by_method)) OVER (), 1)        AS pct_of_amount,
       ROUND(AVG(ot.order_paid), 2)                          AS avg_order_value,
       ROUND(AVG(p.installments), 1)                         AS avg_installments
FROM pay p
JOIN order_total ot ON ot.order_id = p.order_id
GROUP BY p.payment_type
ORDER BY amount_paid DESC;


-- ---------------------------------------------------------------------
-- Q8. REPEAT vs ONE-TIME CUSTOMERS
-- customer_id is new for every order in Olist, so a real customer is
-- identified by customer_unique_id.
-- ---------------------------------------------------------------------
WITH cust_orders AS (
    SELECT c.customer_unique_id,
           COUNT(DISTINCT o.order_id) AS orders,
           SUM(oi.price)              AS revenue
    FROM customers c
    JOIN orders o       ON o.customer_id = c.customer_id
    JOIN order_items oi ON oi.order_id   = o.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY c.customer_unique_id
),
segmented AS (
    SELECT *, CASE WHEN orders = 1 THEN 'One-time customer'
                   ELSE 'Repeat customer (2+ orders)' END AS segment
    FROM cust_orders
)
SELECT segment,
       COUNT(*)                                             AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)   AS pct_of_customers,
       SUM(orders)                                          AS orders,
       ROUND(SUM(revenue), 2)                               AS revenue,
       ROUND(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 1) AS pct_of_revenue,
       ROUND(AVG(revenue), 2)                               AS avg_revenue_per_customer,
       ROUND(1.0 * SUM(orders) / COUNT(*), 2)               AS avg_orders_per_customer
FROM segmented
GROUP BY segment
ORDER BY customers DESC;
