with source as (
    select
        id,
        name,
        email,
        registration_date,
        country,
        _loaded_at,
        _source_file
    from {{ source('raw', 'customers') }}
)

select
    id as customer_id,
    name as customer_name,
    email,
    registration_date::timestamp as registration_date,
    country,
    _loaded_at,
    _source_file
from source
