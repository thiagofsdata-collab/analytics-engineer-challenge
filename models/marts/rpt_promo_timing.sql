with orders as (
    select
        order_date,
        header_total_usd
    from {{ ref('fct_orders') }}
)

select
    extract(hour from order_date) as order_hour,
    count(*) as order_count,
    sum(header_total_usd) as total_revenue_usd
from orders
group by 1
