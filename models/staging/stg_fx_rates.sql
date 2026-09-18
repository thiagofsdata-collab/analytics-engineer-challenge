with source as (
    select
        responses,
        _loaded_at,
        _source_file
    from {{ source('raw', 'fx_rates') }}
),

flattened as (
    select
        unnest(responses) as response,
        _loaded_at,
        _source_file
    from source
)

select
    response.base as base_currency,
    response.date::date as rate_date,
    response.rates as rates,
    _loaded_at,
    _source_file
from flattened
