select count(*) as null_revenue_count
from {{ ref('int_order_items_enriched') }}
where revenue_usd is null
having count(*) != 75
