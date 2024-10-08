USE `gdb023`;

-- 1. Provide the list of markets in which customer  "Atliq  Exclusive"  operates its business in the  APAC  region. 
select market
from dim_customer
where customer = "Atliq Exclusive" and region = "APAC"

-- 2.  What is the percentage of unique product increase in 2021 vs. 2020? The 
-- final output contains these fields, 
-- unique_products_2020 
-- unique_products_2021 
-- percentage_chg

SELECT 
  COUNT(DISTINCT CASE WHEN fiscal_year = 2020 THEN product_code END) AS unique_2020,
  COUNT(DISTINCT CASE WHEN fiscal_year = 2021 THEN product_code END) AS unique_2021,
  
  ROUND(
    (
      COUNT(DISTINCT CASE WHEN fiscal_year = 2021 THEN product_code END) - 
      COUNT(DISTINCT CASE WHEN fiscal_year = 2020 THEN product_code END)
    ) * 100.0 / 
    COUNT(DISTINCT CASE WHEN fiscal_year = 2020 THEN product_code END), 
    2
  ) AS percentage_change

FROM fact_sales_monthly;


-- 3. Provide a report with all the unique product counts for each  segment  and sort them in descending order of product counts. 
-- The final output contains 2 fields, segment ,product_count 
select segment,count(distinct product_code) as product_count
from dim_product
group by segment
order by product_count desc

-- 4. Follow-up: Which segment had the most increase in unique products in 2021 vs 2020?
-- The final output contains these fields, segment ,product_count_2020 ,product_count_2021 ,difference

WITH unique_cte as (
select 
	count(distinct case when fiscal_year = 2021 then sm.product_code end ) product_count_2021,  
	count(distinct case when fiscal_year = 2020 then sm.product_code end ) product_count_2020,
    segment
from fact_sales_monthly as sm
left join dim_product as dp
	on sm.product_code = dp.product_code
group by segment
)
select 
segment,
product_count_2020,
product_count_2021,
(product_count_2021 - product_count_2020) as difference
from unique_cte
group by segment


-- 5  Get the products that have the highest and lowest manufacturing costs. 
-- The final output should contain these fields, product_code ,product ,manufacturing_cost
select fmc.product_code,product,manufacturing_cost
from fact_manufacturing_cost fmc
left join dim_product dp
	on fmc.product_code = dp.product_code 
    where manufacturing_cost in (
		select max(manufacturing_cost) from fact_manufacturing_cost 
        union 
        select min(manufacturing_cost) from fact_manufacturing_cost
    )
order by manufacturing_cost desc

-- 6. Generate a report which contains the top 5 customers who received an average high  pre_invoice_discount_pct  for the  fiscal  year 2021  and in the Indian  market.
-- The final output contains these fields, customer_code ,customer ,average_discount_percentage 

select fpid.customer_code,
customer,
round(avg(pre_invoice_discount_pct),5) *100 as average_discount_percentage
from fact_pre_invoice_deductions fpid
join  dim_customer dc
	on fpid.customer_code = dc.customer_code
where fiscal_year = 2021 
and dc.market = 'india'
group by fpid.customer_code,customer
order by average_discount_percentage desc
limit 5

-- 7. Get the complete report of the Gross sales amount for the customer  “Atliq Exclusive”  for each month  . 
 -- This analysis helps to  get an idea of low and high-performing months and take strategic decisions. 
 -- The final report contains these columns: Month, Year ,Gross sales Amount

SELECT 
    CONCAT(MONTHNAME(fsm.date), ' (', YEAR(fsm.date), ')') AS Month,
    fsm.fiscal_year,
    ROUND(SUM(fsm.sold_quantity * fgp.gross_price), 3) AS gross_sales_amount
from
    fact_sales_monthly fsm  
join 
    fact_gross_price fgp ON fsm.product_code = fgp.product_code
join dim_customer dc
on fsm.customer_code = dc.customer_code
where customer = 'Atliq Exclusive'
group by  month ,fsm.fiscal_year
order by fiscal_year




-- 8. In which quarter of 2020, got the maximum total_sold_quantity? The final output contains these fields sorted by the total_sold_quantity: Quarter ,total_sold_quantity 
select 
	case 
		WHEN date BETWEEN '2019-09-01' AND '2019-11-01' then CONCAT('[',1,']' ,  MONTHNAME(date),'',year(date))
		WHEN date BETWEEN '2019-12-01' AND '2020-02-01' THEN CONCAT('[', 2, '] ', MONTHNAME(date),'',year(date))
		WHEN date BETWEEN '2020-03-01' AND '2020-05-01' THEN CONCAT('[', 3, '] ', MONTHNAME(date),'',year(date))
		WHEN date BETWEEN '2020-06-01' AND '2020-08-01' THEN CONCAT('[', 4, '] ', MONTHNAME(date),'',year(date))
	END as quarters,
sum(sold_quantity) as total_sold_quantity
from fact_sales_monthly
where fiscal_year = 2020
group by quarters
order by  total_sold_quantity desc


-- 9. Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution?  The final output  contains these fields, channel ,gross_sales_mln ,percentage 
with gsales as (
select 
channel,
round(sum(gross_price * sold_quantity/1000000),2)  as gross_sales_mln
from fact_gross_price as fgp
join fact_sales_monthly as fsm
on fgp.product_code = fsm.product_code
join dim_customer dc
on dc.customer_code = fsm.customer_code 
where fgp.fiscal_year = 2021
group by channel
)
select
 channel,
gross_sales_mln,
 CONCAT(ROUND(Gross_sales_mln * 100 / (SELECT SUM(gross_sales_mln) FROM gsales) , 2), ' %') AS percentage
 from gsales
 ORDER BY percentage DESC 
 
 -- 10. Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? The final output contains these :
 -- fields, division, product_code,product ,total_sold_quantity ,rank_order 
 with cte1 as  (
 select dp.division,fsm.product_code,dp.product,sum(sold_quantity) as Total_sold_quantity
 from dim_product dp
 join fact_sales_monthly fsm 
 on dp.product_code = fsm.product_code
 where fiscal_year = 2021
 group by dp.division,fsm.product_code,dp.product
 ),
 cte2 as (
 SELECT division, product_code, product, Total_sold_quantity,
        RANK() OVER(PARTITION BY division ORDER BY Total_sold_quantity DESC) AS 'Rank_Order' 
FROM cte1
)
SELECT cte1.division, cte1.product_code, cte1.product, cte2.Total_sold_quantity, cte2.Rank_Order
 FROM cte1 JOIN cte2
 ON cte1.product_code = cte2.product_code
WHERE cte2.Rank_Order IN (1,2,3)
