CREATE TABLE amazon_brazil.customers (
    customer_id VARCHAR PRIMARY KEY,
    customer_unique_id VARCHAR,
    customer_zip_code_prefix INTEGER
);

CREATE TABLE amazon_brazil.orders (
    order_id VARCHAR PRIMARY KEY,
    customer_id VARCHAR,
    order_status VARCHAR,
    order_purchase_timestamp TIMESTAMP,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES amazon_brazil.customers(customer_id)
);

CREATE TABLE amazon_brazil.payments (
    order_id VARCHAR,
    payment_sequential INTEGER,
    payment_type VARCHAR,
    payment_installments INTEGER,
    payment_value NUMERIC, # was INTEGER
    PRIMARY KEY (order_id, payment_sequential),
    FOREIGN KEY (order_id) REFERENCES amazon_brazil.orders(order_id)
);

CREATE TABLE amazon_brazil.seller (
    seller_id VARCHAR PRIMARY KEY,
    seller_zip_code_prefix INTEGER
);

CREATE TABLE amazon_brazil.product (
    product_id VARCHAR PRIMARY KEY,
    product_category_name VARCHAR,
    product_name_length INTEGER,
    product_description_length INTEGER,
    product_photos_qty INTEGER,
    product_weight_g INTEGER,
    product_length_cm INTEGER,
    product_height_cm INTEGER,
    product_width_cm INTEGER
);

CREATE TABLE amazon_brazil.order_items (
    order_id VARCHAR,
    order_item_id INTEGER,
    product_id VARCHAR,
    seller_id VARCHAR,
    shipping_limit_date TIMESTAMP,
    price NUMERIC,
    freight_value NUMERIC,
    PRIMARY KEY (order_id, order_item_id),
    FOREIGN KEY (order_id) REFERENCES amazon_brazil.orders(order_id),
    FOREIGN KEY (product_id) REFERENCES amazon_brazil.product(product_id),
    FOREIGN KEY (seller_id) REFERENCES amazon_brazil.seller(seller_id)
);

-- --ANALYSIS 1 

-- --Q1 Round the average payment values to integer (no decimal) for each payment type and display the results sorted in ascending order.
-- --Output: payment_type, rounded_avg_payment

SELECT payment_type, ROUND(AVG(payment_value)) AS rounded_avg_payment
FROM amazon_brazil.payments
GROUP BY payment_type
ORDER BY rounded_avg_payment ASC;



-- --Q2 Calculate the percentage of total orders for each payment type, rounded to one decimal place, and display them in descending order
-- --Output: payment_type, percentage_orders

SELECT payment_type,
       ROUND(COUNT(*) * 100.0 / total_orders, 1) AS percentage_orders
FROM amazon_brazil.payments,
     (SELECT COUNT(*) AS total_orders FROM amazon_brazil.payments) AS totals
GROUP BY payment_type, total_orders
ORDER BY percentage_orders DESC



-- --Q3 Identify all products priced between 100 and 500 BRL that contain the word 'Smart' in their name. Display these products, sorted by price in descending order.
-- --Output: product_id, price

SELECT distinct
    oi.product_id,
    oi.price
FROM amazon_brazil.order_items oi
JOIN amazon_brazil.product p ON oi.product_id = p.product_id
WHERE oi.price BETWEEN 100 AND 500
  AND p.product_category_name ILIKE '%Smart%'
ORDER BY oi.price DESC;




-- --Q4 Determine the top 3 months with the highest total sales value, rounded to the nearest integer.
-- --Output: month, total_sales

SELECT EXTRACT(MONTH FROM o.order_purchase_timestamp) AS month,
       ROUND(SUM(oi.price)) AS total_sales
FROM amazon_brazil.orders o
JOIN amazon_brazil.order_items oi ON o.order_id = oi.order_id
GROUP BY month
ORDER BY total_sales DESC
LIMIT 3;




-- --Q5 Find categories where the difference between the maximum and minimum product prices is greater than 500 BRL.
-- --Output: product_category_name, price_difference


SELECT p.product_category_name, MAX(oi.price) - MIN(oi.price) AS price_difference
FROM amazon_brazil.order_items oi
join amazon_brazil.product p on oi.product_id = p.product_id
GROUP BY p.product_category_name
HAVING MAX(oi.price) - MIN(oi.price) > 500;



-- --Q6  Identify the payment types with the least variance in transaction amounts, sorting by the smallest standard deviation first.
-- --Output: payment_type, std_deviation

SELECT payment_type, STDDEV(payment_value) AS std_deviation
FROM amazon_brazil.payments
GROUP BY payment_type
ORDER BY std_deviation ASC;



-- --Q7 Retrieve the list of products where the product category name is missing or contains only a single character.
-- --Output: product_id, product_category_name


SELECT product_id, product_category_name
FROM amazon_brazil.product
WHERE product_category_name IS NULL
   OR LENGTH(product_category_name) <= 1;



-- Analysis 2


-- 1) Segment order values into three ranges: orders less than 200 BRL, between 200 and 1000 BRL, and over 1000 BRL. Calculate the count of each payment type within these ranges and display the results in descending order of count

-- Output: order_value_segment, payment_type, count

with order_values as (
select o.order_id, sum(oi.price) as total_val from amazon_brazil.orders o
join amazon_brazil.order_items oi on o.order_id = oi.order_id
group by o.order_id
),
order_segments as (
select ov.order_id,
case
when ov.total_val < 200 then 'Low'
when ov.total_val between 200 and 1000 then 'Medium'
else 'High'
end as order_value_segment
from order_values ov
)

select os.order_value_segment, p.payment_type, count(*) as count
from order_segments os join amazon_brazil.payments p
on os.order_id  = p.order_id
group by os.order_value_segment,payment_type
order by count desc



-- 2) Calculate the minimum, maximum, and average price for each category, and list them in descending order by the average price.

-- Output: product_category_name, min_price, max_price, avg_price


select p.product_category_name, min(oi.price),max(oi.price),avg(oi.price) from amazon_brazil.product p
join amazon_brazil.order_items oi
on p.product_id = oi.product_id
group by p.product_category_name
order by avg(oi.price) desc




-- 3)Find all customers with more than one order, and display their customer unique IDs along with the total number of orders they have placed.

-- Output: customer_unique_id, total_orders


select c.customer_unique_id, count(distinct o.order_id) as total_orders from amazon_brazil.customers c
join amazon_brazil.orders o
on c.customer_id = o.customer_id
group by customer_unique_id
having count(distinct o.order_id)>1
order by total_orders desc






-- 4) Use a temporary table to define these categories and join it with the customers table to update and display the customer types.

-- Output: customer_unique_id, customer_type

with customer_order_count as(
select c.customer_unique_id, count(distinct o.order_id) as order_count from amazon_brazil.customers c
left join amazon_brazil.orders o
on c.customer_id = o.customer_id
group by customer_unique_id
)

select customer_unique_id,
case 
when order_count =1 then 'New'
when order_count between 2 and 4 then 'Returning'
when order_count > 4 then 'Loyal'
else 'No Orders'
end  as customer_type
from customer_order_count



-- 5) Use joins between the tables to calculate the total revenue for each product category. Display the top 5 categories.

-- Output: product_category_name, total_revenue

SELECT 
    p.product_category_name,
    SUM(oi.price) AS total_revenue
FROM amazon_brazil.order_items oi
JOIN amazon_brazil.product p ON oi.product_id = p.product_id
GROUP BY p.product_category_name
ORDER BY total_revenue DESC
LIMIT 5;


-- Analysis 3

-- 1)The marketing team wants to compare the total sales between different seasons. Use a subquery to calculate total sales for each season (Spring, Summer, Autumn, Winter) based on order purchase dates, and display the results. Spring is in the months of March, April and May. Summer is from June to August and Autumn is between September and November and rest months are Winter. 
-- Output: season, total_sales

with season_sales as(
select o.order_id, sum(oi.price) as order_total, o.order_purchase_timestamp from amazon_brazil.orders o
join amazon_brazil.order_items oi on o.order_id = oi.order_id
group by o.order_id,o.order_purchase_timestamp
)

select
case
when extract(month from order_purchase_timestamp) in (3,4,5) then 'Spring'
when extract(month from order_purchase_timestamp) in (6,7,8) then 'Summer'
when extract(month from order_purchase_timestamp) in (9,10,11) then 'Autumn'
else 'Winter'
end as Season,
sum(order_total) as total_sales
from season_sales
group by season


-- 2)The inventory team is interested in identifying products that have sales volumes above the overall average. Write a query that uses a subquery to filter products with a total quantity sold above the average quantity.
-- Output: product_id, total_quantity_sold

with sales as(
select product_id,count(order_item_id) as total_quantity from amazon_brazil.order_items
group by product_id
),

average_sales as (
select avg(total_quantity) as avg_quantity from sales
)
-- AVERAGE QUANTITY = 3
select product_id, total_quantity from sales
where total_quantity> (select avg_quantity from average_sales)


-- 3)To understand seasonal sales patterns, the finance team is analysing the monthly revenue trends over the past year (year 2018). Run a query to calculate total revenue generated each month and identify periods of peak and low sales. Export the data to Excel and create a graph to visually represent revenue changes across the months. 
-- Output: month, total_revenue

select extract(month from o.order_purchase_timestamp) as month, sum(oi.price) as total_revenue from amazon_brazil.orders o 
join amazon_brazil.order_items oi
on o.order_id = oi.order_id
where extract(year from o.order_purchase_timestamp) = 2018
group by month
order by month

-- 3b)

with monthly_revenue as(
select extract(month from o.order_purchase_timestamp) as month, sum(oi.price) as total_revenue from amazon_brazil.orders o 
join amazon_brazil.order_items oi
on o.order_id = oi.order_id
where extract(year from o.order_purchase_timestamp) = 2018
group by month
order by month
)

select month, total_revenue from monthly_revenue
where total_revenue = (select max(total_revenue) from monthly_revenue) or
total_revenue = (select min(total_revenue) from monthly_revenue)

-- 4)A loyalty program is being designed  for Amazon India. Create a segmentation based on purchase frequency: ‘Occasional’ for customers with 1-2 orders, ‘Regular’ for 3-5 orders, and ‘Loyal’ for more than 5 orders. Use a CTE to classify customers and their count and generate a chart in Excel to show the proportion of each segment.
-- Output: customer_type, count
with customer_order_count as(
select c.customer_unique_id, count(distinct o.order_id) as order_count from amazon_brazil.customers c
left join amazon_brazil.orders o
on c.customer_id = o.customer_id
group by customer_unique_id
)

select
case 
when order_count BETWEEN 1 AND 2 then 'Occasional'
when order_count between 3 and 5 then 'Regular'
when order_count > 5 then 'Loyal'
else 'No Orders'
end  as customer_type, count(*) as customer_count
from customer_order_count
group by customer_type




-- 5)Amazon wants to identify high-value customers to target for an exclusive rewards program. You are required to rank customers based on their average order value (avg_order_value) to find the top 20 customers.
-- Output: customer_id, avg_order_value, and customer_rank

WITH order_totals AS (
  SELECT
    o.order_id,
    o.customer_id,
    SUM(oi.price) AS order_value
  FROM amazon_brazil.orders o
  JOIN amazon_brazil.order_items oi ON o.order_id = oi.order_id
  GROUP BY o.order_id, o.customer_id
),
customer_avg_order_value AS (
  SELECT
    c.customer_unique_id,
    AVG(ot.order_value) AS avg_order_value
  FROM amazon_brazil.customers c
  JOIN order_totals ot ON c.customer_id = ot.customer_id
  GROUP BY c.customer_unique_id
)
SELECT
  customer_unique_id AS customer_id,
  avg_order_value,
  RANK() OVER (ORDER BY avg_order_value DESC) AS customer_rank
FROM customer_avg_order_value
ORDER BY customer_rank
LIMIT 20;


-- 6)Amazon wants to analyze sales growth trends for its key products over their lifecycle. Calculate monthly cumulative sales for each product from the date of its first sale. Use a recursive CTE to compute the cumulative sales (total_sales) for each product month by month.
-- Output: product_id, sale_month, and total_sales

WITH RECURSIVE product_monthly_sales AS (
  SELECT
    oi.product_id,
    DATE_TRUNC('month', o.order_purchase_timestamp) AS sale_month,
    SUM(oi.price) AS monthly_sales
  FROM amazon_brazil.order_items oi
  JOIN amazon_brazil.orders o ON oi.order_id = o.order_id
  GROUP BY oi.product_id, sale_month
),

product_first_month AS (
  SELECT
    product_id,
    MIN(sale_month) AS first_month
  FROM product_monthly_sales
  GROUP BY product_id
),

recursive_monthly_cumsum AS (
  -- Anchor member: first sale month sales per product
  SELECT
    pms.product_id,
    pms.sale_month,
    pms.monthly_sales AS total_sales
  FROM product_monthly_sales pms
  JOIN product_first_month pfm 
    ON pms.product_id = pfm.product_id 
    AND pms.sale_month = pfm.first_month

  UNION ALL

  -- Recursive member: cumulative sales by adding next month sales
  SELECT
    pms.product_id,
    pms.sale_month,
    rms.total_sales + pms.monthly_sales AS total_sales
  FROM recursive_monthly_cumsum rms
  JOIN product_monthly_sales pms 
    ON rms.product_id = pms.product_id 
    AND pms.sale_month = rms.sale_month + INTERVAL '1 month'
)

SELECT 
  product_id, 
  sale_month, 
  total_sales
FROM recursive_monthly_cumsum
ORDER BY product_id, sale_month;



-- 7)To understand how different payment methods affect monthly sales growth, Amazon wants to compute the total sales for each payment method and calculate the month-over-month growth rate for the past year (year 2018). Write query to first calculate total monthly sales for each payment method, then compute the percentage change from the previous month.
-- Output: payment_type, sale_month, monthly_total, monthly_change.

WITH monthly_sales AS (
  SELECT
    p.payment_type,
    DATE_TRUNC('month', o.order_purchase_timestamp) AS sale_month,
    SUM(p.payment_value) AS monthly_total
  FROM amazon_brazil.payments p
  JOIN amazon_brazil.orders o ON p.order_id = o.order_id
  WHERE EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2018
  GROUP BY p.payment_type, sale_month
),
monthly_sales_with_lag AS (
  SELECT
    payment_type,
    sale_month,
    monthly_total,
    LAG(monthly_total) OVER (PARTITION BY payment_type ORDER BY sale_month) AS prev_month_total
  FROM monthly_sales
)
SELECT
  payment_type,
  sale_month,
  monthly_total,
  CASE 
    WHEN prev_month_total IS NULL OR prev_month_total = 0 THEN NULL
    ELSE ((monthly_total - prev_month_total) / prev_month_total) * 100
  END AS monthly_change
FROM monthly_sales_with_lag
ORDER BY payment_type, sale_month;
