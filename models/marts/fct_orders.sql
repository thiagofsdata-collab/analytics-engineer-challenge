with orders as (
    select
        order_id,
        customer_id,
        order_date,
        total_amount,
        currency,
        is_valid_currency_code
    from {{ ref('stg_orders') }}
),

fx as (
    select rate_date, currency, rate_to_usd
    from {{ ref('int_fx_usd') }}
),

header as (
    select
        orders.order_id,
        orders.customer_id,
        orders.order_date,
        orders.currency,
        orders.is_valid_currency_code,
        orders.total_amount * fx.rate_to_usd as header_total_usd
    from orders
    left join fx
        on orders.order_date::date = fx.rate_date
        and orders.currency = fx.currency
),

items_rollup as (
    select
        order_id,
        count(*) as item_count,
        sum(revenue_usd) as items_rollup_total_usd
    from {{ ref('fct_order_items') }}
    group by order_id
)

select
    header.order_id,
    header.customer_id,
    header.order_date,
    header.currency,
    header.is_valid_currency_code,
    header.header_total_usd,
    coalesce(items_rollup.item_count, 0) as item_count,
    items_rollup.items_rollup_total_usd,
    case
        when items_rollup.items_rollup_total_usd is null then null
        when header.header_total_usd is null then null
        else abs(header.header_total_usd - items_rollup.items_rollup_total_usd) > 0.01
    end as has_revenue_discrepancy
from header
left join items_rollup on header.order_id = items_rollup.order_id
