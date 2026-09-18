with order_items as (
    select
        order_item_id,
        order_id,
        product_id,
        quantity,
        unit_price,
        currency as item_currency,
        is_valid_currency_code,
        is_product_id_orphan
    from {{ ref('stg_order_items') }}
),

orders as (
    select
        order_id,
        order_date,
        currency as order_currency
    from {{ ref('stg_orders') }}
),

fx as (
    select
        rate_date,
        currency,
        rate_to_usd,
        fx_rate_source
    from {{ ref('int_fx_usd') }}
),

joined as (
    select
        order_items.order_item_id,
        order_items.order_id,
        order_items.product_id,
        order_items.quantity,
        order_items.unit_price,
        order_items.item_currency,
        order_items.is_valid_currency_code,
        order_items.is_product_id_orphan,
        orders.order_date,
        orders.order_currency,
        fx.rate_to_usd,
        fx.fx_rate_source
    from order_items
    left join orders on order_items.order_id = orders.order_id
    left join fx
        on orders.order_date::date = fx.rate_date
        and order_items.item_currency = fx.currency
)

select
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    item_currency,
    order_currency,
    order_currency != item_currency as has_currency_mismatch,
    is_valid_currency_code,
    is_product_id_orphan,
    order_date,
    rate_to_usd,
    fx_rate_source,
    quantity * unit_price * rate_to_usd as revenue_usd
from joined
