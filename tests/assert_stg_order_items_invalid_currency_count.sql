select count(*) as invalid_currency_count
from {{ ref('stg_order_items') }}
where not is_valid_currency_code
having count(*) != 75
