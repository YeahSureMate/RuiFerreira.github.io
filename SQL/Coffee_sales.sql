-- Top sold beverage
SELECT 
	coffee_name, 
    COUNT(*) as Total_sales
FROM coffee_sales
GROUP BY coffee_name
ORDER BY Total_sales DESC;

-- Top highest revenue
SELECT
	coffee_name,
	ROUND(SUM(money),2) as total_revenue
FROM coffee_sales
GROUP BY coffee_name
ORDER BY Total_revenue DESC;

-- Total sales and revenue per month
SELECT 
	date_format(date, '%Y-%m') as month,
	COUNT(*) as total_sales,
    SUM(money) as total_revenue
FROM coffee_sales
GROUP BY month;

-- Average price for each coffee beverage
-- The same product has multiple price points in the dataset
-- This variation is due to marketing strategies
-- and differences in cash vs card transactions (cards include 1 UAH commission)
SELECT 
	coffee_name,
	ROUND(avg(money),2) as average_price
FROM coffee_sales
GROUP BY coffee_name;

-- Peak hours
SELECT 
	date_format(datetime, '%H') AS hour,
	COUNT(*) as total_sales
FROM coffee_sales
GROUP BY hour
ORDER by hour;

-- Number of sales (card vs cash)
SELECT 
	cash_type, COUNT(*) as total_sales,
	avg(money) as average_paid
FROM coffee_sales
GROUP BY cash_type;






