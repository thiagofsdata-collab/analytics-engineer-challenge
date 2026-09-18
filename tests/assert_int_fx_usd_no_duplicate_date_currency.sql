select rate_date, currency, count(*) as n
from {{ ref('int_fx_usd') }}
group by 1, 2
having count(*) > 1
