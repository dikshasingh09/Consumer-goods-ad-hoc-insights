#"These MySQL queries are tailored for the Consumer Goods Ad-hoc Insights Challenge, providing targeted analysis and insights."

# Req 1. 
# Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.

SELECT distinct market
FROM dim_customer
WHERE 
customer like "Atliq Exclusive" and 
region like "APAC";

 --------------------------------------------------------------------------------------------
# Req 2. 
# What is the percentage of unique product increase in 2021 vs. 2020? 

WITH product_counts AS (
    SELECT 
        fiscal_year,
        COUNT(DISTINCT product_code) AS unique_products_count
    FROM 
        fact_sales_monthly
    GROUP BY 
        fiscal_year
)
SELECT
    p2020.unique_products_count AS unique_products_2020,
    p2021.unique_products_count AS unique_products_2021,
    CONCAT(ROUND((p2021.unique_products_count - p2020.unique_products_count) / p2020.unique_products_count * 100, 2), '%') AS percentage_chg
FROM
    product_counts p2020
JOIN
    product_counts p2021 ON p2020.fiscal_year = 2020 AND p2021.fiscal_year = 2021;
    
    
   -------------------------------------------------------------------------------------------- 
    
# Req 3.
# Provide a report with all the unique product counts for each  segment  and  sort them in descending order of product counts.

SELECT
    segment,
    COUNT(DISTINCT product_code) AS unique_product_count
FROM
    dim_product
GROUP BY
    segment
ORDER BY
    unique_product_count DESC;


-------------------------------------------------------------------------------------------- 
# Req 4.
# Which segment had the most increase in unique products in 2021 vs 2020?

WITH cte1 as (
			SELECT count(distinct(product_code)) as unique_products,
				   dp.segment, fs.fiscal_year
			FROM dim_product as dp
			join fact_sales_monthly as fs
			using (product_code)
			GROUP BY dp.segment, fs.fiscal_year
			)
SELECT  a.segment,
		a.unique_products as product_count_2020,
		b.unique_products as product_count_2021,
	    (b.unique_products - a.unique_products) as difference
	FROM cte1 as a
	left join cte1 as b
	on a.fiscal_year+1 = b.fiscal_year and a.segment = b.segment
    WHERE a.unique_products and b.unique_products is not null
    ORDER BY difference desc;
    
    -------------------------------------------------------------------------------------------- 
# Req 5.
# Get the products that have the highest and lowest manufacturing costs.

SELECT 
    dp.product_code, 
    dp.product, 
    mc.manufacturing_cost
FROM 
    fact_manufacturing_cost AS mc
JOIN 
    dim_product AS dp USING (product_code)
WHERE 
    mc.manufacturing_cost IN (
        (SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost),
        (SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost)
    );
    
    
       -------------------------------------------------------------------------------------------- 

# Req 6.
    #  Generate a report which contains the top 5 customers who received an average high  pre_invoice_discount_pct  for the  fiscal  year 2021  and in the Indian  market.
    SELECT 
    fs.customer_code,
    dc.customer,
    CONCAT(ROUND(AVG(fs.pre_invoice_discount_pct) * 100, 2), '%') AS average_discount_percentage
FROM 
    fact_pre_invoice_deductions AS fs
JOIN 
    dim_customer AS dc ON fs.customer_code = dc.customer_code
WHERE 
    fs.fiscal_year = 2021
    AND dc.market = 'India'
GROUP BY 
    fs.customer_code, dc.customer
ORDER BY 
    AVG(fs.pre_invoice_discount_pct) DESC
limit 5 ;

   -------------------------------------------------------------------------------------------- 
# Req 7.
# Get the complete report of the Gross sales amount for the customer  “Atliq Exclusive”  for each month  .  This analysis helps to  get an idea of low and  high-performing months and take strategic decisions. 

SELECT 
    CONCAT(MONTHNAME(fs.date)) AS Month,
    YEAR(fs.date) AS Year,
    fs.fiscal_year, 
    ROUND(SUM(fg.gross_price * fs.sold_quantity), 2) AS gross_sales_amount,
    ROUND(SUM(fg.gross_price * fs.sold_quantity) - LAG(SUM(fg.gross_price * fs.sold_quantity), 1) OVER (ORDER BY fs.fiscal_year), 2) AS gross_sales_difference
FROM 
    fact_sales_monthly fs
INNER JOIN 
    fact_gross_price fg ON fg.product_code = fs.product_code AND fg.fiscal_year = fs.fiscal_year
INNER JOIN 
    dim_customer dc ON dc.customer_code = fs.customer_code
WHERE 
    dc.customer = 'Atliq Exclusive'
GROUP BY 
    Month, Year, fs.fiscal_year
ORDER BY 
    fs.fiscal_year;
   -------------------------------------------------------------------------------------------- 
# Req 8.
#  In which quarter of 2020, got the maximum total_sold_quantity?  
#Note that fiscal_year for Atliq Hardware starts from September(09)

SELECT 
    'Qtr-1' AS Quarter,
    SUM(sold_quantity) AS total_quantity_sold
FROM 
    fact_sales_monthly
WHERE 
    YEAR(date) = 2020
    AND MONTH(date) IN (9, 10, 11)
UNION ALL
SELECT 
    'Qtr-2' AS Quarter,
    SUM(sold_quantity) AS total_quantity_sold
FROM 
    fact_sales_monthly
WHERE 
    YEAR(date) = 2020
    AND MONTH(date) IN (12, 1, 2)
UNION ALL
SELECT 
    'Qtr-3' AS Quarter,
    SUM(sold_quantity) AS total_quantity_sold
FROM 
    fact_sales_monthly
WHERE 
    YEAR(date) = 2020
    AND MONTH(date) IN (3, 4, 5)
UNION ALL
SELECT 
    'Qtr-4' AS Quarter,
    SUM(sold_quantity) AS total_quantity_sold
FROM 
    fact_sales_monthly
WHERE 
    YEAR(date) = 2020
    AND MONTH(date) IN (6, 7, 8);
   -------------------------------------------------------------------------------------------- 
# Req 9.
#  Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution?

WITH cte1 AS (
    SELECT
        dc.channel,
        ROUND(SUM(fs.sold_quantity * fg.gross_price) / 1000000, 2) AS gross_sales_mln
    FROM
        fact_gross_price AS fg
    JOIN
        fact_sales_monthly AS fs ON fs.product_code = fg.product_code
    JOIN
        dim_customer AS dc ON dc.customer_code = fs.customer_code
    WHERE
        fg.fiscal_year = 2021
    GROUP BY
        dc.channel
)
SELECT
    channel,
    CONCAT(gross_sales_mln, ' M') AS gross_sales_mln,
    CONCAT(ROUND(gross_sales_mln / (SELECT SUM(gross_sales_mln) FROM cte1) * 100, 2), ' %') AS pct_contribution
FROM
    cte1;

   -------------------------------------------------------------------------------------------- 
# Req 10.
#  Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021?

WITH d_rank AS (
    SELECT 
        dp.division, 
        fs.product_code,
        dp.product, 
        SUM(fs.sold_quantity) AS total_sold_quantity,
        RANK() OVER (PARTITION BY dp.division ORDER BY SUM(fs.sold_quantity) DESC) AS rank_order
    FROM 
        dim_product AS dp
    JOIN 
        fact_sales_monthly AS fs USING (product_code)
    WHERE 
        fs.fiscal_year = 2021 
    GROUP BY 
        dp.division, 
        fs.product_code,
        dp.product
)
SELECT 
    division,
    product_code,
    product,
    total_sold_quantity,
    rank_order
FROM 
    d_rank 
WHERE 
    rank_order <= 3;
