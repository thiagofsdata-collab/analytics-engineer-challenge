with source as (
    select
        id,
        name,
        category,
        description,
        base_price,
        currency,
        _loaded_at,
        _source_file
    from {{ source('raw', 'products') }}
)

select
    id as product_id,
    name as product_name,
    category,
    description,
    base_price::double as base_price,
    currency,
    _loaded_at,
    _source_file
from source
