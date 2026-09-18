with counts as (
    select source_table, dq_reason, count(*) as n
    from {{ ref('dq_exceptions') }}
    group by 1, 2
),

expected as (
    select 'orders' as source_table, 'invalid_currency_code' as dq_reason, 79 as expected_n
    union all
    select 'order_items', 'invalid_currency_code', 75
    union all
    select 'order_items', 'orphan_product_id', 71
)

select
    expected.source_table,
    expected.dq_reason,
    expected.expected_n,
    coalesce(counts.n, 0) as actual_n
from expected
left join counts
    on expected.source_table = counts.source_table
    and expected.dq_reason = counts.dq_reason
where coalesce(counts.n, 0) != expected.expected_n
