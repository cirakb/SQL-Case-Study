--CASE STUDY PROJECT--

-- CIRAK BELAI
-- 11/15/2022
-- MS SQL Server (MYSQL SERVER WORKBENCH)

CREATE SCHEMA dannys_diner;
SET search_path = dannys_diner;

CREATE TABLE sales (
  customer_id VARCHAR(1),
  order_date DATE,
  product_id INTEGER
);

INSERT INTO sales
  (customer_id, order_date, product_id)
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
 

CREATE TABLE menu (
  product_id INTEGER,
  product_name VARCHAR(5),
  price INTEGER
);

INSERT INTO menu
  (product_id, product_name, price)
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  

CREATE TABLE members (
  customer_id VARCHAR(1),
  join_date DATE
);

INSERT INTO members
  (customer_id, join_date)
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');
  
SELECT * FROM sales;

--WORKED SOLUTIONS

## 1. What is the total amount each customer spent at the restaurant?
SELECT customer_id, SUM(price)
FROM sales
	INNER JOIN menu
    ON sales.product_id = menu.product_id
    GROUP BY customer_id;
    
## 2. How many days has each customer visited the restaurant?
SELECT customer_id, COUNT(order_date)
FROM sales 
GROUP BY customer_id;

## 3. What was the first item from the menu purchased by each customer?
SELECT customer_id, product_name
FROM
(
  SELECT 
  customer_id, 
  product_name,
  RANK() OVER (partition by customer_id ORDER BY order_date) AS purchase_rank
  FROM sales 
  INNER JOIN menu
  ON sales.product_id = menu.product_id
) AS temp_table

WHERE purchase_rank = 1;

## 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT product_name, COUNT(*) AS times_purchased
FROM sales
	INNER JOIN menu 
    ON sales.product_id = menu.product_id
GROUP BY product_name
LIMIT 1;

## 5. Which item was the most popular for each customer?
SELECT customer_id, product_name, times_purchased
FROM
(
  SELECT
  customer_id,
  product_name,
  COUNT(*) AS times_purchased,
  DENSE_RANK() OVER(PARTITION BY customer_id ORDER BY COUNT(*) DESC) AS purchase_rank
  FROM sales
 	INNER JOIN menu
 	ON sales.product_id = menu.product_id
  GROUP BY customer_id, product_name
) AS temp_table
  
WHERE purchase_rank = 1; 

## 6. Which item was purchased first by the customer after they became a member? 
WITH after_members_cte AS (
  SELECT 
  s.customer_id, 
  m.join_date, 
  s.order_date, 
  s.product_id,
  DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date) AS date_rank
FROM dannys_diner.sales AS s
  INNER JOIN dannys_diner.members AS m
  ON s.customer_id = m.customer_id
WHERE s.order_date >= m.join_date
)

SELECT 
	s1.customer_id,
    m.product_name AS first_order,
    s1.order_date
FROM after_members_cte AS s1 
	INNER JOIN menu AS m
    ON s1.product_id = m.product_id 
WHERE date_rank = 1;

## 7. Which item was purchased just before the customer became a member?
WITH before_members_cte AS (
SELECT 
  s.customer_id, 
  m.join_date, 
  s.order_date, 
  s.product_id,
  DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date DESC) AS date_rank
FROM sales AS s
  INNER JOIN members AS m
  ON s.customer_id = m.customer_id
WHERE s.order_date < m.join_date
)

SELECT 
	s.customer_id,
    m1.product_name AS first_order,
    s.order_date
FROM before_members_cte AS s 
	INNER JOIN menu AS m1
    ON s.product_id = m1.product_id 
WHERE date_rank = 1;

## 8. What is the total items and amount spent for each member before they became a member?
WITH sales_members_cte AS(
  SELECT 
  	s.customer_id,
  	s.product_id,
  	s.order_date
  	FROM sales AS s
  		INNER JOIN members AS m
  		ON s.customer_id = m.customer_id
	WHERE s.order_date < m.join_date
)   
    
SELECT 
	s.customer_id,
    COUNT(DISTINCT m1.product_id) AS total_items, 
    SUM (m1.price) AS total_price
FROM sales_members_cte AS s
	INNER JOIN menu AS m1
    ON s.product_id = m1.product_id
GROUP BY s.customer_id;

## 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
WITH points_cte AS (
  SELECT *,
  CASE
  	WHEN product_id = 1 THEN price * 20
  	ELSE price * 10
  END AS points
  FROM menu)
  
SELECT 
	s.customer_id, 
    SUM(p.points) AS total_points
FROM points_cte AS p
	INNER JOIN sales AS s 
    ON p.product_id = s.product_id
GROUP BY s.customer_id
ORDER BY total_points DESC;

## 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

-- 1. Find member validity date of each customer and get last date of January
-- 2. Use CASE WHEN to allocate points by date and product id
-- 3. SUM price and points
WITH
 first_week_program
AS
 (
  SELECT
   s.customer_id, 
   CASE WHEN m.product_name = 'sushi' AND
    s.order_date BETWEEN ms.join_date + CAST(-1 || 'day' AS INTERVAL) 
   AND
    ms.join_date + cast(6 || 'day' AS INTERVAL) THEN m.price*20
   WHEN product_name = 'sushi' OR
    s.order_date BETWEEN ms.join_date + CAST(-1 || 'day' AS INTERVAL) 
   AND
   ms.join_date + CAST(6 || 'day' AS INTERVAL) THEN m.price*20
   ELSE m.price*10 END AS points
  FROM members ms
  LEFT JOIN sales s 
  ON s.customer_id = ms.customer_id
  LEFT JOIN menu m 
  ON s.product_id = m.product_id
  WHERE s.order_date <= '20210131'
 )

SELECT customer_id, SUM(points) points
FROM first_week_program
GROUP BY customer_id;
