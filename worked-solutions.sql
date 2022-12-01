--------------------------------
--CASE STUDY #1: DANNY'S DINER--
--------------------------------

--Author: Cirak Belai
--Date: 11/15/2022
--Tool used: Microsoft SQL Server (MySQL Workbench)

## 1. What is the total amount each customer spent at the restaurant?

SELECT customer_id, SUM(price)
FROM dannys_diner.sales 
	INNER JOIN dannys_diner.menu
    ON sales.product_id = menu.product_id
GROUP BY customer_id; 


## 2. How many days has each customer visited the restaurant?

SELECT customer_id, COUNT(order_date)
FROM dannys_diner.sales 
GROUP BY customer_id;

## 3. What was the first item from the menu purchased by each customer?

SELECT customer_id, product_name
FROM
(
  SELECT 
  customer_id, 
  product_name,
  RANK() OVER (partition by customer_id ORDER BY order_date) AS purchase_rank
  FROM dannys_diner.sales 
  INNER JOIN dannys_diner.menu
  ON sales.product_id = menu.product_id
) AS temp_table

WHERE purchase_rank = 1;

## 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT product_name, COUNT(*) AS times_purchased
FROM dannys_diner.sales
	INNER JOIN dannys_diner.menu 
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
  FROM dannys_diner.sales
 	INNER JOIN dannys_diner.menu
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
	INNER JOIN dannys_diner.menu AS m
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
FROM dannys_diner.sales AS s
  INNER JOIN dannys_diner.members AS m
  ON s.customer_id = m.customer_id
WHERE s.order_date < m.join_date
)

SELECT 
	s.customer_id,
    m1.product_name AS first_order,
    s.order_date
FROM before_members_cte AS s 
	INNER JOIN dannys_diner.menu AS m1
    ON s.product_id = m1.product_id 
WHERE date_rank = 1;


## 8. What is the total items and amount spent for each member before they became a member?

WITH sales_members_cte AS(
  SELECT 
  	s.customer_id,
  	s.product_id,
  	s.order_date
  	FROM dannys_diner.sales AS s
  		INNER JOIN dannys_diner.members AS m
  		ON s.customer_id = m.customer_id
	WHERE s.order_date < m.join_date
)   
    
SELECT 
	s.customer_id,
    COUNT(DISTINCT m1.product_id) AS total_items, 
    SUM (m1.price) AS total_price
FROM sales_members_cte AS s
	INNER JOIN dannys_diner.menu AS m1
    ON s.product_id = m1.product_id
GROUP BY s.customer_id;
  	

## 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

WITH points_cte AS (
  SELECT *,
  CASE
  	WHEN product_id = 1 THEN price * 20
  	ELSE price * 10
  END AS points
  FROM dannys_diner.menu)
  
SELECT 
	s.customer_id, 
    SUM(p.points) AS total_points
FROM points_cte AS p
	INNER JOIN dannys_diner.sales AS s 
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
  FROM dannys_diner.members ms
  LEFT JOIN dannys_diner.sales s 
  ON s.customer_id = ms.customer_id
  LEFT JOIN dannys_diner.menu m 
  ON s.product_id = m.product_id
  WHERE s.order_date <= '20210131'
 )

SELECT customer_id, SUM(points) points
FROM first_week_program
GROUP BY customer_id;
