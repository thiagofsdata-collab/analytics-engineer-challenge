with source as (
    select
        id,
        customer_id,
        order_date,
        total_amount,
        currency,
        status,
        _loaded_at,
        _source_file
    from {{ source('raw', 'orders') }}
)

select
    id as order_id,
    customer_id,
    order_date::timestamp as order_date,
    total_amount::double as total_amount,
    currency,
    status,
    currency in ('USD', 'EUR', 'GBP') as is_valid_currency_code,
    _loaded_at,
    _source_file
from source
