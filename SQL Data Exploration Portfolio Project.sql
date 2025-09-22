-- Top Product Categories by Number of items

SELECT
  pct.product_category_name_english,
  COUNT(*) AS total_items,
  ROUND(SUM(oi.price), 2) AS total_revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN product_category_name_translation pct
  ON p.product_category_name = pct.product_category_name
GROUP BY pct.product_category_name_english
ORDER BY total_items DESC
LIMIT 10;

-- Total orders by month

SELECT
  strftime('%Y-%m', order_purchase_timestamp) AS order_month,
  COUNT(*) AS total_orders
FROM orders
GROUP BY order_month
ORDER BY order_month DESC;

-- Popular Payment Types and Value

SELECT
  payment_type,
  COUNT(*) AS payment_count,
  ROUND(SUM(payment_value), 2) AS total_payment_value
FROM order_payments
GROUP BY payment_type
ORDER BY payment_count DESC;

-- Average Delivery Time by customer_city

SELECT
  c.customer_city,
  ROUND(AVG(DATEDIFF(day,o.order_purchase_timestamp,o.order_delivered_customer_date)), 2) AS avg_delivery_days,
  COUNT(*) AS total_orders
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY avg_delivery_days DESC;

-- Seller Performance: Avg Review & Delivery Time

SELECT
  oi.seller_id,s.seller_city,
  ROUND(AVG(r.review_score), 2) AS avg_review_score,
  ROUND(AVG(DATEDIFF(day,o.order_purchase_timestamp,o.order_delivered_customer_date)), 2) AS avg_delivery_days,
  COUNT(DISTINCT o.order_id) AS total_orders
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN sellers s ON oi.seller_id = s.seller_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY s.seller_city
ORDER BY avg_review_score DESC
LIMIT 10;

-- Repeat Customer Percentage
-- Calculate percentage of customers who ordered more than once

WITH customer_order_counts AS (
    SELECT
        customer_unique_id,
        COUNT(DISTINCT order_id) AS order_count
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY customer_unique_id
)
SELECT
    ROUND(100.0 * COUNT(*) FILTER (WHERE order_count > 1) / COUNT(*), 2) AS repeat_customer_percent,
    COUNT(*) FILTER (WHERE order_count > 1) AS repeat_customers,
    COUNT(*) AS total_customers
FROM customer_order_counts;

-- Review Score by Delivery Delay Category

SELECT
  CASE
    WHEN DATEDIFF(day,o.order_estimated_delivery_date,o.order_delivered_customer_date) > 7 THEN 'More than 7 days Late'
    WHEN DATEDIFF(day,o.order_estimated_delivery_date,o.order_delivered_customer_date) BETWEEN 0 AND 7 THEN 'Less than 7 days Late'
    WHEN o.order_delivered_customer_date < o.order_estimated_delivery_date THEN 'Early'
    ELSE 'On Time'
  END AS delivery_status,
  ROUND(AVG(r.review_score), 2) AS avg_review_score,
  COUNT(*) AS total_orders
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY delivery_status;

--Calculate actual vs estimated delivery time in days

WITH delivery_times AS (
    SELECT
        order_id,
        DATEDIFF(day,order_purchase_timestamp,order_delivered_customer_date) AS actual_delivery_days,
        DATEDIFF(day,order_purchase_timestamp,order_estimated_delivery_date) AS estimated_delivery_days
    FROM orders
    WHERE order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
), subquery AS (
  SELECT
    order_id,
    actual_delivery_days,
    estimated_delivery_days,
    CASE
        WHEN actual_delivery_days > estimated_delivery_days THEN 'Late'
        WHEN actual_delivery_days < estimated_delivery_days THEN 'Early'
        ELSE 'On Time'
    END AS delivery_status
FROM delivery_times
), days AS (
SELECT
  order_id,
  actual_delivery_days,
  estimated_delivery_days,
  delivery_status,
  CASE
    WHEN delivery_status = 'Late' THEN ROUND(actual_delivery_days - estimated_delivery_days,0)
    WHEN delivery_status = 'Early' THEN ROUND(estimated_delivery_days - actual_delivery_days,0)
    ELSE 0
  END AS days_difference
FROM subquery
)
SELECT
  order_id,
  actual_delivery_days,
  estimated_delivery_days,
  days_difference,
  delivery_status || ' by ' || CAST(days_difference AS TEXT) || ' days' AS delivery_status
FROM days
ORDER BY days_difference DESC;

--Create the temporary table

CREATE TEMP TABLE high_value_orders2 AS
SELECT
  o.order_id,c.customer_city,
  SUM(oi.price + oi.freight_value) AS total_order_value
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY o.order_id
HAVING total_order_value > 1000;

--Select from the temporary table

SELECT * FROM high_value_orders2 ORDER BY total_order_value DESC;
