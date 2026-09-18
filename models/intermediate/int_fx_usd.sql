with order_dates as (
    select distinct order_date::date as rate_date
    from {{ ref('stg_orders') }}
),

rates_long as (
    select
        base_currency,
        rate_date,
        entry.key as currency_to,
        entry.value as rate
    from {{ ref('stg_fx_rates') }},
    unnest(map_entries(cast(rates as map(varchar, double)))) as t(entry)
),

direct_rates as (
    select
        base_currency as currency,
        rate_date,
        rate as rate_to_usd
    from rates_long
    where currency_to = 'USD'
),

inverted_rates as (
    select
        currency_to as currency,
        rate_date,
        1.0 / rate as rate_to_usd
    from rates_long
    where base_currency = 'USD'
      and currency_to != 'USD'
),

known_rates as (
    select currency, rate_date, rate_to_usd, 'direct' as fx_rate_source
    from direct_rates

    union all

    select inverted_rates.currency, inverted_rates.rate_date, inverted_rates.rate_to_usd, 'inverted' as fx_rate_source
    from inverted_rates
    left join direct_rates
        on inverted_rates.currency = direct_rates.currency
        and inverted_rates.rate_date = direct_rates.rate_date
    where direct_rates.currency is null
),

earliest_known as (
    select
        currency,
        arg_min(rate_to_usd, rate_date) as rate_to_usd,
        arg_min(fx_rate_source, rate_date) as fx_rate_source
    from known_rates
    group by currency
),

spine as (
    select order_dates.rate_date, currencies.currency
    from order_dates
    cross join (select distinct currency from known_rates) as currencies
),

asof_matched as (
    select
        spine.rate_date,
        spine.currency,
        known_rates.rate_to_usd,
        known_rates.fx_rate_source
    from spine
    asof left join known_rates
        on spine.currency = known_rates.currency
        and spine.rate_date >= known_rates.rate_date
),

filled as (
    select
        asof_matched.rate_date,
        asof_matched.currency,
        coalesce(asof_matched.rate_to_usd, earliest_known.rate_to_usd) as rate_to_usd,
        case
            when asof_matched.rate_to_usd is not null then asof_matched.fx_rate_source
            else 'forward_filled'
        end as fx_rate_source
    from asof_matched
    left join earliest_known on asof_matched.currency = earliest_known.currency
)

select
    rate_date,
    currency,
    rate_to_usd,
    fx_rate_source
from filled
