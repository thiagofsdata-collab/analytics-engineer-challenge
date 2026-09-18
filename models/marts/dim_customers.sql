select
    customer_id,
    customer_name,
    email,
    registration_date,
    country
from {{ ref('stg_customers') }}
