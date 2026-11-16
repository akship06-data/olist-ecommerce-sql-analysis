# Olist E-Commerce Supply Chain, Delivery & Revenue Analysis

## Project Overview
An end-to-end data engineering and analytics project examining 100,000+ e-commerce orders across Brazil (2016–2018) from the public [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) on Kaggle. The objective is to ingest raw cloud storage files into a structured relational warehouse, diagnose fulfillment bottlenecks, quantify how shipping delays impact customer review scores, identify underperforming sellers, and track quarterly category revenue growth.

## Tech Stack
PostgreSQL, SQL, Python (`boto3`), AWS S3, Power BI, Git

## Pipeline Architecture
1. **Extract:** Raw Olist CSV files are staged in an AWS S3 bucket.
2. **Load:** A Python (`boto3`) ingestion script reads the CSVs from S3 and loads them into PostgreSQL staging tables.
3. **Transform:** SQL views clean the raw data (timestamp casting, `NULL` filtering, and delivery variance calculations) and model it into a star schema.
4. **Serve:** A Power BI dashboard connects directly to the modeled views for interactive reporting.

## Database Schema
The pipeline integrates 7 relational tables from the Olist dataset:

- `olist_orders_dataset`: Order lifecycle timestamps (purchase, approval, carrier handoff, customer delivery, estimated delivery).
- `olist_order_items_dataset`: Line-item prices, freight values, product IDs, and seller IDs.
- `olist_order_reviews_dataset`: Customer satisfaction ratings (1–5 stars) and review timestamps.
- `olist_customers_dataset`: Unique customer identifiers, cities, and states.
- `olist_sellers_dataset`: Merchant locations and IDs.
- `olist_products_dataset` & `product_category_name_translation`: Product metadata and Portuguese-to-English category mappings.

## Data Model (Star Schema)
- **Fact View (`fact_order_items`):** Central order-item grain combining item price, freight value, actual vs. estimated delivery variance, and customer review scores.
- **Dimension Views (`dim_customers`, `dim_sellers`, `dim_products`, `dim_orders`):** Conformed entity attributes for geographic segmentation, merchant SLA tracking, English product category hierarchies, and order lifecycle timestamps.

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
- `s3_to_postgres.py`: Python script using `boto3` to extract raw CSVs from AWS S3 and load them into PostgreSQL
- `olist_ecommerce_analysis.sql`: SQL DDL/DML script containing star-schema views, data cleaning logic, and analytical queries
- `images/dashboard.png`: Power BI dashboard screenshot
- `README.md`: Project documentation

## How to Run
1. Download the Brazilian E-Commerce Public Dataset by Olist from [Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) and upload the CSVs to your AWS S3 bucket.
2. Configure your AWS credentials (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`) and PostgreSQL connection variables (`DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`), then run `python s3_to_postgres.py` to populate the staging tables.
3. Execute `olist_ecommerce_analysis.sql` sequentially in PostgreSQL to build the star-schema views and generate all analytical outputs.