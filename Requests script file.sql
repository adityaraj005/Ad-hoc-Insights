# 1. Provide the list of markets in which customer  "Atliq  Exclusive"  operates its business in the  APAC  region.
SELECT 
	DISTINCT(market)
FROM
    dim_customer
WHERE
    region = 'APAC'
	AND customer = 'Atliq Exclusive'
ORDER BY market;


# 2.  What is the percentage of unique product increase in 2021 vs. 2020? 
-- The final output contains these fields:
-- unique_products_2020 
-- unique_products_2021 
-- percentage_chg 

WITH product_count AS(SELECT 
    COUNT(DISTINCT CASE 
						WHEN fiscal_year = 2020 THEN product_code 
					END
                    ) AS unique_products_2020,
    COUNT(DISTINCT CASE 
						WHEN fiscal_year = 2021 THEN product_code 
                        END
                        ) AS unique_products_2021
	
FROM fact_sales_monthly
)
SELECT 
    *,
    ROUND((unique_products_2021 - unique_products_2020) * 100 / unique_products_2020, 2) AS percentage_chg
FROM product_count;


# 3. Provide a report with all the unique product counts for each  segment  and 
-- sort them in descending order of product counts. The final output contains 
-- 2 fields, 
-- segment 
-- product_count

SELECT 
    segment, COUNT(DISTINCT product_code) AS product_count
FROM
    dim_product
GROUP BY segment
ORDER BY product_count DESC;


# 4.   Follow-up: Which segment had the most increase in unique products in 
-- 2021 vs 2020? The final output contains these fields, 
-- segment 
-- product_count_2020 
-- product_count_2021 
-- difference 

WITH CTE1 AS (SELECT segment, 
	   COUNT(DISTINCT CASE WHEN fiscal_year = 2020 THEN f.product_code END) AS unique_products_2020,
       COUNT(DISTINCT CASE WHEN fiscal_year = 2021 THEN f.product_code END) AS unique_products_2021
FROM fact_sales_monthly f
JOIN dim_product USING(product_code)
GROUP BY segment
)
SELECT *, (unique_products_2021-unique_products_2020) AS difference FROM CTE1
ORDER BY difference DESC;


# 5 Get the products that have the highest and lowest manufacturing costs. 
-- The final output should contain these fields, 
-- product_code 
-- product 
-- manufacturing_cost

SELECT product_code, product, manufacturing_cost
FROM dim_product join fact_manufacturing_cost using(product_code)
WHERE manufacturing_cost = (SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost)
   OR manufacturing_cost = (SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost);


# 6 Generate a report which contains the top 5 customers who received an 
-- average high  pre_invoice_discount_pct  for the  fiscal  year 2021  and in the 
-- Indian  market. The final output contains these fields, 
-- customer_code 
-- customer 
-- average_discount_percentage 

SELECT 
    c.customer_code, c.customer, AVG(d.pre_invoice_discount_pct) AS average_discount_percentage
FROM
    fact_pre_invoice_deductions d
JOIN
    dim_customer c USING (customer_code)
WHERE 
	d.fiscal_year = 2021 AND c.market = 'India'
GROUP BY 
	c.customer_code , c.customer
ORDER BY 
	average_discount_percentage DESC
LIMIT 5;


# 7 Get the complete report of the Gross sales amount for the customer  “Atliq 
-- Exclusive”  for each month  .  This analysis helps to  get an idea of low and 
-- high-performing months and take strategic decisions. 
-- The final report contains these columns: 
-- Month 
-- Year 
-- Gross sales Amount

SELECT 
    DATE_FORMAT(f.date, '%M') AS "Month", 
    f.fiscal_year AS "Year", 
    CONCAT(round(SUM(f.sold_quantity * g.gross_price / 1000000), 2), 'M')  AS "Gross Sales Amount",
    CONCAT(round(sum((f.sold_quantity * g.gross_price) * (1 - p.pre_invoice_discount_pct) / 1000000), 2), "M")AS Net_Inovice_Sales
FROM 
    fact_sales_monthly f
JOIN 
    fact_gross_price g ON g.product_code = f.product_code AND g.fiscal_year = f.fiscal_year
JOIN fact_pre_invoice_deductions p ON f.fiscal_year = p.fiscal_year AND f.customer_code = p.customer_code
JOIN 
	dim_customer c ON f.customer_code = c.customer_code
WHERE 
	c.customer = "Atliq Exclusive"
GROUP BY 
    f.fiscal_year, f.date
ORDER BY 
    f.fiscal_year;


# 8. In which quarter of 2020, got the maximum total_sold_quantity? The final 
-- output contains these fields sorted by the total_sold_quantity, 
-- Quarter 
-- total_sold_quantity 

SELECT 
	DATE_FORMAT(f.date, '%M') AS "Month",
    CASE 
        WHEN Month(f.date) IN (9, 10, 11) THEN 'Q1'
        WHEN Month(f.date) IN (12, 1, 2) THEN 'Q2'
        WHEN Month(f.date) IN (3, 4, 5) THEN 'Q3'
        WHEN Month(f.date) IN (6, 7, 8) THEN 'Q4'
    END AS "Quarter",
    CONCAT(ROUND(SUM(sold_quantity)/1000000, 2), " M") AS total_sold_quantity
FROM fact_sales_monthly f
WHERE fiscal_year = 2020
GROUP BY 
	f.date,
    CASE 
        WHEN MONTH(f.date) IN (9, 10, 11) THEN 'Q1'
        WHEN MONTH(f.date) IN (12, 1, 2) THEN 'Q2'
        WHEN MONTH(f.date) IN (3, 4, 5) THEN 'Q3'
        WHEN MONTH(f.date) IN (6, 7, 8) THEN 'Q4'
    END
ORDER BY 
    "Month" DESC;
    
    
# 9. Which channel helped to bring more gross sales in the fiscal year 2021 
-- and the percentage of contribution?  The final output  contains these fields, 
-- channel 
-- gross_sales_mln 
-- percentage

SELECT 
    c.channel,
    CONCAT(ROUND(SUM(f.sold_quantity * g.gross_price / 1000000), 2),' M') gross_sales,
    ROUND(SUM(f.sold_quantity * g.gross_price) * 100 / (SELECT 
															SUM(f.sold_quantity * g.gross_price)
														FROM
															fact_sales_monthly f
														JOIN
															fact_gross_price g USING(product_code)
														WHERE 
															f.fiscal_year = 2021),
													2) AS percentage
FROM
    fact_sales_monthly f
JOIN
    dim_customer c USING (customer_code)
JOIN
    fact_gross_price g USING (product_code)
WHERE
    f.fiscal_year = 2021
GROUP BY c.channel
ORDER BY gross_sales DESC;


# 10.  Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? 
-- The final output contains these fields, 
-- division 
-- product_code 
-- product 
-- total_sold_quantity 
-- rank_order 

WITH total_sold_quantity AS (SELECT 
				p.division,
				p.product_code,
				CONCAT(p.product, ' [', p.variant, ']') AS product,
				SUM(f.sold_quantity) AS total_sold_quantity
			  FROM
				fact_sales_monthly f
			  JOIN
				dim_product p USING (product_code)
			  WHERE
				fiscal_year = 2021
			  GROUP BY p.division , p.product_code , p.product , p.variant
			  ORDER BY total_sold_quantity DESC
             ),
	get_rank AS (SELECT *, 
					DENSE_RANK() OVER(PARTITION BY division ORDER BY total_sold_quantity DESC) AS rank_order
			 FROM 
				CTE1
			)
            
SELECT *
FROM get_rank
WHERE rank_order <= 3
     