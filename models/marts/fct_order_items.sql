with enriched as (
    select
        order_item_id,
        order_id,
        product_id,
        is_product_id_orphan,
        order_date,
        quantity,
        unit_price,
        item_currency,
        is_valid_currency_code,
        rate_to_usd,
        fx_rate_source,
        revenue_usd
    from {{ ref('int_order_items_enriched') }}
)

select
    order_item_id,
    order_id,
    case when is_product_id_orphan then -1 else product_id end as product_id,
    order_date,
    quantity,
    unit_price,
    item_currency,
    is_valid_currency_code,
    is_product_id_orphan,
    rate_to_usd,
    fx_rate_source,
    revenue_usd
from enriched
