select sum(item_count) as total_items
from {{ ref('fct_orders') }}
having sum(item_count) != (select count(*) from {{ ref('fct_order_items') }})
