/* ============================================================================
   PROJECT: Olist E-Commerce Supply Chain, Delivery & Revenue Analysis
   DIALECT: PostgreSQL
   DATASET: Brazilian E-Commerce Public Dataset by Olist (100k+ orders)
   DESCRIPTION: End-to-end SQL pipeline diagnosing delivery bottlenecks, 
                quantifying shipping delay impact on review scores, and 
                tracking quarterly category revenue growth.
   ============================================================================ */

-- ============================================================================
-- 1. DATA CLEANING & BASE REPORTING VIEW
-- ============================================================================
-- Creates a clean base view filtering out canceled/unavailable orders and 
-- casting timestamps to standard dates while calculating delivery variance.

DROP VIEW IF EXISTS v_clean_delivered_orders;

CREATE VIEW v_clean_delivered_orders AS
SELECT 
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    o.order_status,
    CAST(o.order_purchase_timestamp AS TIMESTAMP) AS purchase_ts,
    CAST(o.order_approved_at AS TIMESTAMP) AS approved_ts,
    CAST(o.order_delivered_carrier_date AS TIMESTAMP) AS carrier_ts,
    CAST(o.order_delivered_customer_date AS TIMESTAMP) AS delivered_ts,
    CAST(o.order_estimated_delivery_date AS TIMESTAMP) AS estimated_ts,
    -- Positive value = delivered early; Negative value = delivered late
    EXTRACT(DAY FROM (
        CAST(o.order_estimated_delivery_date AS TIMESTAMP) - 
        CAST(o.order_delivered_customer_date AS TIMESTAMP)
    )) AS days_early_or_late,
    CASE 
        WHEN CAST(o.order_delivered_customer_date AS TIMESTAMP) > CAST(o.order_estimated_delivery_date AS TIMESTAMP) 
            THEN 'Late'
        ELSE 'On-Time / Early'
    END AS delivery_status
FROM olist_orders_dataset o
JOIN olist_customers_dataset c 
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL;


-- ============================================================================
-- 2. DELIVERY DELAYS VS. CUSTOMER REVIEW SCORES
-- ============================================================================
-- Quantifies how shipping delays directly erode customer satisfaction scores.

SELECT 
    v.delivery_status,
    CASE 
        WHEN v.days_early_or_late >= 0 THEN '0. On-Time or Early'
        WHEN v.days_early_or_late BETWEEN -3 AND -1 THEN '1. 1-3 Days Late'
        WHEN v.days_early_or_late BETWEEN -7 AND -4 THEN '2. 4-7 Days Late'
        ELSE '3. Over 7 Days Late'
    END AS delay_bucket,
    COUNT(DISTINCT v.order_id) AS total_orders,
    ROUND(
        COUNT(DISTINCT v.order_id)::NUMERIC * 100.0 / 
        SUM(COUNT(DISTINCT v.order_id)) OVER (), 2
    ) AS pct_of_orders,
    ROUND(AVG(r.review_score)::NUMERIC, 2) AS avg_review_score,
    ROUND(
        SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END)::NUMERIC * 100.0 / 
        COUNT(r.review_id), 2
    ) AS pct_negative_reviews
FROM v_clean_delivered_orders v
JOIN olist_order_reviews_dataset r 
    ON v.order_id = r.order_id
GROUP BY 1, 2
ORDER BY 2 ASC;


-- ============================================================================
-- 3. REGIONAL & SELLER FULFILLMENT BOTTLENECKS (GROUP BY, HAVING, JOINS)
-- ============================================================================
-- Identifies high-volume sellers (> 30 orders) with the highest late-delivery rates.

WITH seller_performance AS (
    SELECT 
        s.seller_id,
        s.seller_city,
        s.seller_state,
        COUNT(DISTINCT v.order_id) AS total_orders,
        SUM(CASE WHEN v.delivery_status = 'Late' THEN 1 ELSE 0 END) AS late_orders,
        ROUND(AVG(oi.price + oi.freight_value)::NUMERIC, 2) AS avg_order_value
    FROM v_clean_delivered_orders v
    JOIN olist_order_items_dataset oi 
        ON v.order_id = oi.order_id
    JOIN olist_sellers_dataset s 
        ON oi.seller_id = s.seller_id
    GROUP BY s.seller_id, s.seller_city, s.seller_state
    HAVING COUNT(DISTINCT v.order_id) >= 30
)
SELECT 
    seller_id,
    seller_city,
    seller_state,
    total_orders,
    late_orders,
    ROUND((late_orders::NUMERIC / total_orders) * 100, 2) AS late_delivery_rate_pct,
    avg_order_value,
    RANK() OVER (ORDER BY (late_orders::NUMERIC / total_orders) DESC) AS worst_sla_rank
FROM seller_performance
ORDER BY late_delivery_rate_pct DESC
LIMIT 15;


-- ============================================================================
-- 4. TOP PRODUCT CATEGORIES BY QUARTER & REVENUE SHARE (CTEs + WINDOW FUNCTIONS)
-- ============================================================================
-- Translates Portuguese category names to English and ranks the top 3 revenue-
-- generating categories per quarter using DENSE_RANK().

WITH quarterly_category_sales AS (
    SELECT 
        DATE_TRUNC('quarter', v.purchase_ts)::DATE AS sales_quarter,
        COALESCE(t.product_category_name_english, p.product_category_name, 'uncategorized') AS category,
        COUNT(DISTINCT v.order_id) AS order_count,
        ROUND(SUM(oi.price)::NUMERIC, 2) AS total_revenue
    FROM v_clean_delivered_orders v
    JOIN olist_order_items_dataset oi 
        ON v.order_id = oi.order_id
    JOIN olist_products_dataset p 
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation t 
        ON p.product_category_name = t.product_category_name
    GROUP BY 1, 2
),
ranked_categories AS (
    SELECT 
        sales_quarter,
        category,
        order_count,
        total_revenue,
        DENSE_RANK() OVER (
            PARTITION BY sales_quarter 
            ORDER BY total_revenue DESC
        ) AS revenue_rank
    FROM quarterly_category_sales
)
SELECT 
    sales_quarter,
    revenue_rank,
    category,
    order_count,
    total_revenue
FROM ranked_categories
WHERE revenue_rank <= 3
ORDER BY sales_quarter ASC, revenue_rank ASC;


-- ============================================================================
-- 5. MONTH-OVER-MONTH (MoM) ORDER & REVENUE GROWTH (LAG WINDOW FUNCTION)
-- ============================================================================
-- Tracks monthly platform revenue, running cumulative revenue, and MoM % growth.

WITH monthly_metrics AS (
    SELECT 
        DATE_TRUNC('month', v.purchase_ts)::DATE AS order_month,
        COUNT(DISTINCT v.order_id) AS total_orders,
        ROUND(SUM(oi.price + oi.freight_value)::NUMERIC, 2) AS gross_merchandise_value
    FROM v_clean_delivered_orders v
    JOIN olist_order_items_dataset oi 
        ON v.order_id = oi.order_id
    GROUP BY 1
)
SELECT 
    order_month,
    total_orders,
    gross_merchandise_value AS monthly_gmv,
    SUM(gross_merchandise_value) OVER (ORDER BY order_month) AS cumulative_gmv,
    LAG(gross_merchandise_value) OVER (ORDER BY order_month) AS prev_month_gmv,
    ROUND(
        (gross_merchandise_value - LAG(gross_merchandise_value) OVER (ORDER BY order_month)) * 100.0 /
        NULLIF(LAG(gross_merchandise_value) OVER (ORDER BY order_month), 0), 2
    ) AS mom_growth_pct
FROM monthly_metrics
ORDER BY order_month ASC;