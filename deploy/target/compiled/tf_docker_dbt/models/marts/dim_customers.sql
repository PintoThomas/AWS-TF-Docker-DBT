-- models/marts/dim_customers.sql

WITH stg_customers AS (
    -- On pointe vers le modèle de Staging grâce à la fonction ref()
    SELECT * FROM "awsdatacatalog"."analytics_dev"."stg_customers"
)

SELECT
    customer_id,
    first_name,
    last_name,
    email,
    signup_date,
    -- Règle métier appliquée dans la couche Marts
    CASE 
        WHEN signup_date >= DATE '2026-01-01' THEN 'Client Récent'
        ELSE 'Client Ancien'
    END AS customer_segment
FROM stg_customers