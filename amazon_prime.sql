UPDATE users
SET payment_information = CASE WHEN payment_information = 'Mastercard' then 'MasterCard'
                          ELSE payment_information END;

-- Which countries do new Amazon Prime users come from?
Select distinct country
FROM users
ORDER BY country;


-- What are the top 5 countries by new user count and year?
WITH ranked_data AS (
    SELECT 
        u.country,  
        extract(year FROM u.membership_start_date) AS year,
        COUNT(u.user_id) AS user_count,
        ROW_NUMBER() OVER (PARTITION BY extract(year FROM u.membership_start_date) 
                           ORDER BY COUNT(u.user_id) DESC) AS rank_no
    FROM users AS u
    GROUP BY u.country, extract(year FROM u.membership_start_date)
)

SELECT 
    rank_no, 
    country, 
    year, 
    user_count
FROM ranked_data
WHERE rank_no <= 5
ORDER BY year, user_count DESC;


-- Which gregoraphical regions bring the most subscribers annually?
SELECT 
    extract(year from membership_start_date) as year,
    region,
    count(user_id) AS user_count
FROM users as u
JOIN countries as c
USING(country)
GROUP BY year, region
ORDER BY year, user_count DESC;


-- What is the gender distribution by country?
SELECT 
    country, 
    gender, 
    count(user_id) as user_count
FROM users
GROUP BY country, gender
ORDER BY country;


-- What is the min, max and average user age across the entire database?
SELECT 
    EXTRACT(YEAR FROM min(age(date_of_birth)))AS min_age,
    EXTRACT(YEAR FROM max(age(date_of_birth))) AS max_age,
    EXTRACT(YEAR FROM avg(age(date_of_birth))) AS avg_age
FROM users;

-- Among which age groups is Amazon Prime most popular?
WITH age_bins AS (
    SELECT 
        user_id,
        EXTRACT (YEAR FROM age(date_of_birth)),
        CASE
            WHEN age(date_of_birth) < interval '28 years' THEN '18-27'
            WHEN age(date_of_birth) < interval '38 years' THEN '28-37'
            WHEN age(date_of_birth) < interval '48 years' THEN '38-47'
            WHEN age(date_of_birth) < interval '58 years' THEN '48-57'
            WHEN age(date_of_birth) < interval '68 years' THEN '58-67'
            WHEN age(date_of_birth) < interval '78 years' THEN '68-77'
            ELSE '78+'
            END AS age_group
    FROM users
)
SELECT age_group, count(*) AS user_count
from age_bins
GROUP BY age_group
ORDER BY user_count DESC;


-- Among which age groups, in a given country, is Amazon Prime most popular?
WITH age_bins AS (
    SELECT 
        user_id,
        country,
        EXTRACT (YEAR FROM age(date_of_birth)),
        CASE
            WHEN age(date_of_birth) < interval '28 years' THEN '18-27'
            WHEN age(date_of_birth) < interval '38 years' THEN '28-37'
            WHEN age(date_of_birth) < interval '48 years' THEN '38-47'
            WHEN age(date_of_birth) < interval '58 years' THEN '48-57'
            WHEN age(date_of_birth) < interval '68 years' THEN '58-67'
            WHEN age(date_of_birth) < interval '78 years' THEN '68-77'
            ELSE '78+'
            END AS age_group
    FROM users
)
SELECT country, age_group, count(*) AS user_count
from age_bins
GROUP BY country, age_group
ORDER BY country, user_count DESC;


---- What is the min, max and average user age per country?
SELECT 
    country,
    EXTRACT(YEAR FROM min(age(date_of_birth)))AS min_age,
    EXTRACT(YEAR FROM max(age(date_of_birth))) AS max_age,
    EXTRACT(YEAR FROM avg(age(date_of_birth))) AS avg_age
FROM users
GROUP BY country
ORDER BY country;


-- What is the most popular month to purchase Amazon Prime?
SELECT
    extract(YEAR FROM membership_start_date) as year,
    EXTRACT(month FROM membership_start_date) as month,
    count(*) as user_count,
    RANK() OVER(
             PARTITION BY EXTRACT(YEAR FROM membership_start_date)
             ORDER BY count(*)DESC
             ) AS ranking
FRom users
GROUP BY year, month
ORDER BY user_count DESC;


-- Which months are equally popular each year to purchase a subscription? (Looking for repeat seasonality)
SELECT 
    a.month,
    b.ranking
FROM
  (SELECT
    extract(YEAR FROM membership_start_date) as year,
    EXTRACT(month FROM membership_start_date) as month,
    count(*) as user_count,
    RANK() OVER(
             PARTITION BY EXTRACT(YEAR FROM membership_start_date)
             ORDER BY count(*)DESC
             ) AS ranking
FRom users
GROUP BY year, month
ORDER BY user_count DESC) AS a
JOIN 
   (SELECT
    extract(YEAR FROM membership_start_date) as year,
    EXTRACT(month FROM membership_start_date) as month,
    count(*) as user_count,
    RANK() OVER(
             PARTITION BY EXTRACT(YEAR FROM membership_start_date)
             ORDER BY count(*)DESC
             ) AS ranking
FRom users
GROUP BY year, month
ORDER BY user_count DESC) AS b
ON a.month = b.month AND a.ranking = b.ranking AND a.year <> b.year;


-- What is the overall min, max, avg and median monthly subscription price in USD?
SELECT 
    min(monthly_price_usd) AS min_price, 
    max(monthly_price_usd) AS max_price, 
    round(avg(monthly_price_usd),2) AS avg_price,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY monthly_price_usd)::decimal(8,2) AS median_price
FROM subscription_prices;


-- What is the min, max, avg and median monthly subscription price by region in USD?
SELECT
    region,
    min(monthly_price_usd) AS min_price, 
    max(monthly_price_usd) AS max_price, 
    round(avg(monthly_price_usd), 2) AS avg_price,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY monthly_price_usd)::decimal(8,2) AS median_price
FROM subscription_prices as sp
JOIN countries as c
USING(country)
GROUP BY region;


-- What is the overall min, max, avg and median annual subscription price in USD?
SELECT 
    min(annual_price_usd) AS min_price, 
    max(annual_price_usd) AS max_price, 
    round(avg(annual_price_usd),2) AS avg_price,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY annual_price_usd) AS median_price
FROM subscription_prices;


-- What is the min, max, avg and median annual subscription price by region in USD?
SELECT 
    region,
    min(annual_price_usd) AS min_price, 
    max(annual_price_usd) AS max_price, 
    round(avg(annual_price_usd),2) AS avg_price,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY annual_price_usd) AS median_price
FROM subscription_prices as sp
JOIN countries as c
USING(country)
GROUP BY region;


-- What discount (in absolute and relative terms) does an annual subscription provide to a subscriber on a monthly basis in a given country?
SELECT 
    country,
    COALESCE(round(((annual_price_usd/12) - monthly_price_usd), 2), 0) AS usd_discount,
    COALESCE(round((((annual_price_usd/12) - monthly_price_usd) / monthly_price_usd), 2), 0) AS percentage_discount
FROM subscription_prices
ORDER BY percentage_discount;


-- Which subscription plan is more popular across countries in a given year?
SELECT 
    country, 
    extract(year from membership_start_date) AS year,
    subscription_plan, 
    count(*) as user_count
FROM users
GROUP BY country, year, subscription_plan
ORDER BY country, year, user_count DESC;


-- How do subscribers prefer to renew their membership across countries?
SELECT 
    country,
    reneval_status,
    count(*) as user_count
FROM users
GROUP by country, reneval_status
ORDER BY country, user_count DESC;


-- What payment method is most popular across US subscribers?
SELECT 
    country,
    payment_information,
    count(*) as user_count
FROM users
WHERE country = 'United States'
GROUP by country, payment_information
ORDER BY user_count DESC;


-- How often do members in the age between 18 and 50, according to gender, use Amazon Prime?
SELECT 
    gender,
    usage_frequncy,
    count(*) as user_count
FROM users
WHERE age(date_of_birth) < interval '51 years'
GROup by gender,usage_frequncy
ORDER BY gender, user_count DESC ;


-- What is the most frequently purchased product category among Prime users by gender and subscription type?
WITH user_counts AS (
    SELECT 
        subscription_plan, 
        gender, 
        purchase_history, 
        COUNT(*) AS user_count
    FROM users
    GROUP BY subscription_plan, gender, purchase_history
),
max_counts AS (
    SELECT 
        subscription_plan, 
        gender, 
        MAX(user_count) AS max_count
    FROM user_counts
    GROUP BY subscription_plan, gender
)
SELECT 
    u.subscription_plan, 
    u.gender, 
    u.purchase_history
FROM user_counts u
JOIN max_counts m
ON u.subscription_plan = m.subscription_plan 
   AND u.gender = m.gender 
   AND u.user_count = m.max_count
ORDER BY u.subscription_plan, u.gender;


-- What are the favorite film/series genres by country and devices used? 
WITH user_counts AS (
    SELECT 
        country, 
        favorite_genres, 
        devices_used, 
        COUNT(*) AS user_count
    FROM users
    GROUP BY country, devices_used, favorite_genres
),
max_counts AS (
    SELECT 
        country, 
        devices_used, 
        MAX(user_count) AS max_count
    FROM user_counts
    GROUP BY country, devices_used
)
SELECT 
    u.country, 
    u.devices_used, 
    u.favorite_genres
FROM user_counts u
JOIN max_counts m
ON u.country = m.country
   AND u.devices_used = m.devices_used
   AND u.user_count = m.max_count
ORDER BY u.country, u.devices_used;


-- How does customer engagement compare to usage frequency by country?
SELECT 
    country, 
    engagement_metrics,
    usage_frequncy,
    count(*) AS user_count
FROM users
GROUP BY country, engagement_metrics, usage_frequncy
ORDER BY country, engagement_metrics, user_count DESC;


-- What are min, max, avg and median feedback ratings across countries
SELECT 
    country,
    min(feedback_ratings) AS min_rating, 
    max(feedback_ratings) AS max_rating, 
    round(avg(feedback_ratings),1) AS avg_rating,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY feedback_ratings)::decimal(8,1) AS median_rating
FROM users
GROUP BY country
ORDER BY country;


-- How many users left bad ratings (< 3.5) per country?
SELECT 
    country, 
    count(*) as user_count, 
    round(count(*)::numeric / (select count(*) from users), 3) AS subscriber_percent
FROM users
WHERE feedback_ratings < 3.5
GROUP BY country;

-- How many users with  > 5 service interactions per country?
SELECT 
    country, 
    count(*) as user_count, 
    round(count(*)::numeric / (select count(*) from users), 3) AS subscriber_percent
FROM users
WHERE customer_support_interactions > 5
GROUP BY country;


-- How many users with > 5 service interactions and who left < 3.5 rating per country?
SELECT 
    country, 
    count(*) as user_count, 
    round(count(*)::numeric / (select count(*) from users), 3) AS subscriber_percent
FROM users
WHERE customer_support_interactions > 5
      AND feedback_ratings < 3.5
GROUP BY country;
