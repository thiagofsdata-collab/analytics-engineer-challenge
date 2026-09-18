with items as (
    select
        product_id,
        quantity,
        revenue_usd
    from {{ ref('fct_order_items') }}
    where product_id != -1
),

products as (
    select product_id, product_name, category
    from {{ ref('dim_products') }}
    where product_id != -1
)

select
    products.product_id,
    products.product_name,
    products.category,
    sum(items.quantity) as total_quantity,
    sum(items.revenue_usd) as total_revenue_usd,
    count(*) as line_item_count
from items
join products on items.product_id = products.product_id
group by 1, 2, 3
