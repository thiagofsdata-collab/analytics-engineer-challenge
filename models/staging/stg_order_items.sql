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
),

products as (
    select product_id from {{ ref('stg_products') }}
)

select
    source.id as order_item_id,
    source.order_id,
    source.product_id,
    source.quantity::integer as quantity,
    source.unit_price::double as unit_price,
    source.currency,
    source.currency in ('USD', 'EUR', 'GBP') as is_valid_currency_code,
    products.product_id is null as is_product_id_orphan,
    source._loaded_at,
    source._source_file
from source
left join products on source.product_id = products.product_id
