select rate_date, currency, fx_rate_source
from {{ ref('int_fx_usd') }}
where currency = 'GBP'
  and rate_date = date '2024-09-15'
  and fx_rate_source != 'inverted'
