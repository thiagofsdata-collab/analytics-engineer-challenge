with source as (
    select
        id,
        order_id,
        product_id,
        quantity,
        unit_price,
        currency,
        _loaded_at,
        _source_file
    from {{ source('raw', 'order_items') }}
)

select
    id as order_item_id,
    order_id,
    product_id,
    quantity::integer as quantity,
    unit_price::double as unit_price,
    currency,
    currency in ('USD', 'EUR', 'GBP') as is_valid_currency_code,
    _loaded_at,
    _source_file
from source
