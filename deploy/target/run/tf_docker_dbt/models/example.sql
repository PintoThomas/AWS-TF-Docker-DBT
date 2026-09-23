create or replace view
    "awsdatacatalog"."analytics_dev"."example"
  as
    -- Un modèle dbt est simplement un SELECT !
-- dbt va exécuter ça et créer une table 'example' sur Athena/S3.
SELECT 
    1 AS id,
    'Projet AWS dbt Docker' AS nom,
    CURRENT_DATE AS date_creation
