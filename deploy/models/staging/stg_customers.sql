-- models/staging/stg_customers.sql

SELECT
    id AS customer_id,
    UPPER(first_name) AS first_name,
    UPPER(last_name) AS last_name,
    LOWER(email) AS email,
    CAST(signup_date AS DATE) AS signup_date
FROM {{ source('raw_data', 'raw_customers') }}