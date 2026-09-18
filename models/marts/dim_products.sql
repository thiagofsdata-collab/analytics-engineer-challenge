with products as (
    select
        product_id,
        product_name,
        category,
        description,
        base_price,
        currency
    from {{ ref('stg_products') }}
),

unknown as (
    select
        -1 as product_id,
        'Unknown' as product_name,
        'Unknown' as category,
        null as description,
        null::double as base_price,
        null as currency
),

unioned as (
    select product_id, product_name, category, description, base_price, currency from products
    union all
    select product_id, product_name, category, description, base_price, currency from unknown
)

select
    product_id,
    product_name,
    category,
    description,
    base_price,
    currency
from unioned
