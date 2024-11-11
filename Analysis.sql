											                                                  -- Data Analysis Questions

-- How many customers has Foodie-Fi ever had?

SELECT count(DISTINCT customer_id) AS total_customers
FROM subscriptions;

-- What is the monthly distribution of trial plan start_date values for our dataset - use the start of the month as the group by value

SELECT 
    MONTH(start_date) AS month,
    YEAR(start_date) AS year,
    COUNT(*) AS trial_count
FROM subscriptions
WHERE plan_id = 0
GROUP BY YEAR(start_date), MONTH(start_date)
ORDER BY YEAR(start_date), MONTH(start_date);


-- What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name

SELECT plan_name, 
	   year(start_date) as year, count(*) total_subscriptions
FROM subscriptions s
join plans p on s.plan_id = p.plan_id
WHERE year(start_date) > 2020
GROUP BY plan_name, year(start_date);

-- What is the customer count and percentage of customers who have churned rounded to 1 decimal place?
WITH latest_subscriptions AS (
    SELECT customer_id, 
           plan_id, 
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY start_date DESC) AS rn
    FROM subscriptions
)
SELECT 
    COUNT(CASE WHEN plan_id = 4 AND rn = 1 THEN customer_id END) AS churn_customers,
    ROUND(
        COUNT(CASE WHEN plan_id = 4 AND rn = 1 THEN customer_id END) * 100.0 / 
        COUNT(DISTINCT customer_id), 1
    ) AS churn_customers_percentage 
FROM latest_subscriptions
WHERE rn = 1;



-- How many customers have churned straight after their initial free trial - what percentage is this rounded to the nearest whole number?
WITH trial_customers AS(
	SELECT customer_id, min(start_date) as trial_join_date
    FROM subscriptions
    WHERE plan_id = 0
    GROUP BY customer_id
),
churn_customers AS(
	SELECT customer_id, min(start_date) as churn_date
    FROM subscriptions 
    WHERE plan_id = 4
    GROUP BY customer_id
)
SELECT count(c.customer_id) as churned_customers_after_trial,
	   round(count(c.customer_id) / (select count(customer_id) from subscriptions where plan_id = 0) * 100, 2) as percentage_churned
FROM trial_customers t
JOIN churn_customers c on t.customer_id = c.customer_id AND churn_date > trial_join_date
WHERE c.customer_id NOT IN (SELECT customer_id FROM subscriptions WHERE plan_id in (1,2,3));


-- Count and percentage breakdown of customers who converted to a paid plan after their initial free trial?
WITH trial_customers AS(
	SELECT customer_id, min(start_date) as trial_start_date
    FROM subscriptions 
    WHERE plan_id = 0
    GROUP BY customer_id
),
paid_customers as(
	SELECT customer_id, min(start_date) AS plan_start_date
    FROM subscriptions
    WHERE plan_id in (1,2,3)
    GROUP BY customer_id
)
SELECT count(p.customer_id) AS converted_customers,
	   round(count(p.customer_id) / (SELECT count(customer_id) FROM subscriptions WHERE plan_id = 0) * 100, 2) AS percentage_subscribed
FROM trial_customers t
JOIN paid_customers p on t.customer_id = p. customer_id AND plan_start_date > trial_start_date;

    
-- What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?

WITH latest_subscription AS (
    SELECT 
        customer_id, 
        plan_id,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY start_date DESC) AS rn
    FROM subscriptions
    WHERE start_date <= '2020-12-31'
)
SELECT 
    plan_id, 
    COUNT(customer_id) AS total_customers,
    ROUND((COUNT(customer_id) * 100.0 / 
          (SELECT COUNT(DISTINCT customer_id) FROM subscriptions WHERE start_date <= '2020-12-31')), 2) AS percentage
FROM latest_subscription
WHERE rn = 1
GROUP BY plan_id
ORDER BY percentage DESC;

-- How many customers have upgraded to an annual plan in 2020?

WITH not_annual AS(
	SELECT customer_id, min(start_date) as plan_start_date
    FROM subscriptions 
    WHERE plan_id != 3
    GROUP BY customer_id
),
annual_plan AS(
	SELECT customer_id, min(start_date)  as plan_start_date
    FROM subscriptions
    WHERE plan_id = 3
    GROUP BY customer_id
)
SELECT count(a.customer_id) as total_annual_plans
FROM not_annual n
JOIN annual_plan a ON n.customer_id = a.customer_id AND n.plan_start_date < a.plan_start_date
WHERE year(a.plan_start_date) = "2020";


-- How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?
WITH not_annual AS(
	SELECT customer_id, min(start_date) as basic_plan_start_date
    FROM subscriptions 
    WHERE plan_id != 3
    GROUP BY customer_id
),
annual_plan AS(
	SELECT customer_id, min(start_date)  as annual_plan_start_date
    FROM subscriptions
    WHERE plan_id = 3
    GROUP BY customer_id
)
SELECT round(AVG(datediff(annual_plan_start_date, basic_plan_start_date)), 2) AS average_time_days
FROM not_annual n
JOIN annual_plan a ON n.customer_id = a.customer_id 
WHERE annual_plan_start_date >= basic_plan_start_date;

-- Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)

WITH not_annual AS (
    SELECT customer_id, MIN(start_date) AS basic_plan_start_date
    FROM subscriptions 
    WHERE plan_id != 3
    GROUP BY customer_id
),
annual_plan AS (
    SELECT customer_id, MIN(start_date) AS annual_plan_start_date
    FROM subscriptions
    WHERE plan_id = 3
    GROUP BY customer_id
)
SELECT 
    TIMESTAMPDIFF(MONTH, n.basic_plan_start_date, a.annual_plan_start_date) AS months_to_upgrade,
    COUNT(n.customer_id) AS customers_count
FROM not_annual n
JOIN annual_plan a 
    ON n.customer_id = a.customer_id
WHERE a.annual_plan_start_date > n.basic_plan_start_date
GROUP BY months_to_upgrade
ORDER BY customers_count desc;

-- How many customers downgraded from a pro monthly to a basic monthly plan in 2020?

WITH basic_monthly AS(
	SELECT customer_id, min(start_date) as plan_start_date
    FROM subscriptions 
    WHERE plan_id = 1 
    GROUP BY customer_id
),
monthly_pro AS(
	SELECT customer_id, min(start_date)  as plan_start_date
    FROM subscriptions
    WHERE plan_id = 2
    GROUP BY customer_id
)
SELECT count(bm.customer_id) as total_downgraded_plans
FROM basic_monthly bm
JOIN monthly_pro mp ON bm.customer_id = mp.customer_id AND bm.plan_start_date > mp.plan_start_date
WHERE year(bm.plan_start_date) = "2020";
