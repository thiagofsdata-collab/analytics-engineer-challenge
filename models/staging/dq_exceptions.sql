with orders_invalid_currency as (
    select
        'orders' as source_table,
        order_id::varchar as record_id,
        'invalid_currency_code' as dq_reason,
        currency as dq_detail
    from {{ ref('stg_orders') }}
    where not is_valid_currency_code
),

order_items_invalid_currency as (
    select
        'order_items' as source_table,
        order_item_id::varchar as record_id,
        'invalid_currency_code' as dq_reason,
        currency as dq_detail
    from {{ ref('stg_order_items') }}
    where not is_valid_currency_code
),

order_items_orphan_product as (
    select
        'order_items' as source_table,
        order_item_id::varchar as record_id,
        'orphan_product_id' as dq_reason,
        product_id::varchar as dq_detail
    from {{ ref('stg_order_items') }}
    where is_product_id_orphan
),

unioned as (
    select source_table, record_id, dq_reason, dq_detail from orders_invalid_currency
    union all
    select source_table, record_id, dq_reason, dq_detail from order_items_invalid_currency
    union all
    select source_table, record_id, dq_reason, dq_detail from order_items_orphan_product
)

select
    source_table,
    record_id,
    dq_reason,
    dq_detail
from unioned
