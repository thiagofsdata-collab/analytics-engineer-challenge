with counts as (
    select fx_rate_source, count(*) as n
    from {{ ref('int_fx_usd') }}
    group by 1
),

expected as (
    select 'direct' as fx_rate_source, 435 as expected_n
    union all
    select 'inverted', 108
    union all
    select 'forward_filled', 165
)

select
    expected.fx_rate_source,
    expected.expected_n,
    coalesce(counts.n, 0) as actual_n
from expected
left join counts on expected.fx_rate_source = counts.fx_rate_source
where coalesce(counts.n, 0) != expected.expected_n
