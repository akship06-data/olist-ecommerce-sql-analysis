# Olist E-Commerce Supply Chain, Delivery & Revenue Analysis

## Project Overview
An end-to-end data project examining 100,000+ e-commerce orders across Brazil (2016–2018) from the public [Olist Brazilian E-Commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) on Kaggle. The objective is to diagnose fulfillment bottlenecks, quantify how shipping delays impact customer review scores, identify underperforming sellers, and track quarterly category revenue growth.

## Tech Stack
PostgreSQL, SQL, Python (boto3), AWS S3, Power BI, Git

## Pipeline Architecture
1. **Extract:** Raw Olist CSVs are stored in an AWS S3 bucket.
2. **Load:** A Python (`boto3`) script loads the files from S3 into PostgreSQL.
3. **Transform:** SQL views clean the data (timestamp casting, `NULL` filtering, delivery variance) and model it into a star schema.
4. **Serve:** A Power BI dashboard reads the modeled tables.

## Database Schema
The analysis integrates 7 relational tables from the Olist dataset:

- `olist_orders_dataset`: Order lifecycle timestamps (purchase, approval, carrier handoff, customer delivery, estimated delivery).
- `olist_order_items_dataset`: Line-item prices, freight values, product IDs, and seller IDs.
- `olist_order_reviews_dataset`: Customer satisfaction ratings (1–5 stars) and review timestamps.
- `olist_customers_dataset`: Unique customer identifiers, cities, and states.
- `olist_sellers_dataset`: Merchant locations and IDs.
- `olist_products_dataset` & `product_category_name_translation`: Product metadata and Portuguese-to-English category mappings.

## Data Model (Star Schema)
- **Fact table:** [your fact table name] (price, freight value, delivery variance, review score)
- **Dimensions:** [your dimension table names, e.g. customers, sellers, products, dates]

## SQL Skills Demonstrated
- **Data Cleaning & Views:** Built reusable `CREATE VIEW` logic handling timestamp casting, `NULL` filtering, and delivery variance calculation.
- **Multi-Table Joins & Filtering:** Connected orders, items, reviews, customers, sellers, and translated product categories using `INNER` and `LEFT JOIN`s alongside `GROUP BY` and `HAVING` thresholds.
- **Window Functions & CTEs:** Applied multi-step Common Table Expressions (`WITH`), `DENSE_RANK()` for quarterly category leaderboards, `LAG()` for month-over-month GMV growth, and running totals (`SUM() OVER`).
- **Business Segmentation:** Used `CASE WHEN` bucketing to isolate late-delivery severity tiers.

## Dashboard
![Power BI dashboard](images/dashboard.png)

## Key Findings & Recommendations
1. **Shipping delays severely erode customer ratings:** Orders delivered on time or early average ~4.29 stars, whereas orders delayed by more than 7 days drop below 1.75 stars, with a sharp spike in 1- and 2-star reviews.
   *Recommendation:* Implement automated carrier escalation alerts once a shipment passes 48 hours of its carrier handoff deadline.
2. **Concentrated seller bottlenecks:** Filtering for high-volume merchants (30+ orders) reveals a small subset of sellers with late-delivery rates exceeding 25%–35%.
   *Recommendation:* Enforce stricter Service Level Agreement (SLA) penalties and adjust estimated delivery buffers for repeat late-shipping merchants.
3. **Top revenue-driving categories:** Categories such as `bed_bath_table`, `health_beauty`, and `watches_gifts` consistently anchor top quarterly revenue rankings.
   *Recommendation:* Prioritize inventory forecasting and promotional campaigns around these core categories ahead of Q4 peak demand.

## Repository Structure
- `olist_ecommerce_analysis.sql`: All queries, views, and analysis
- `[your python script name].py`: Loads data from S3 into PostgreSQL
- `images/dashboard.png`: Power BI dashboard screenshot
- `README.md`: Project documentation

## How to Run
1. Download the Brazilian E-Commerce Public Dataset by Olist from [Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce).
2. Upload the CSVs to an S3 bucket and run the Python script to load them into PostgreSQL.
3. Execute `olist_ecommerce_analysis.sql` sequentially to build the views and generate all analytical outputs.
