# Design notes

## Data quality findings

Fonte: `notebooks/01_eda.ipynb`, contra `data/raw/*` direto, sem ingestão.

**Volume**: customers 50, orders 453, order_items 363, products 100. `id` único em orders,
order_items, customers.

**Orders sem item**: 93/453 (20.5%).

**Moeda inválida** (`ABC`, `XYZ`, `QWE`, fora da ISO 4217): orders 79/453 (17.4%),
order_items 75/363 (20.7%). Primeira ocorrência: 2024-08-03.
→ moeda inválida não descarta a linha; `revenue_usd` fica null, linha entra em `dq_exceptions`.

**Produto órfão**: `order_items.product_id` em 101–110, 71/363 itens (19.6%), sem correspondência
em `products.json` (que vai de 1 a 100).
→ `dim_products` com membro desconhecido (id 101–110 → "Unknown"); linha permanece no fato.

**Sobreposição dos dois acima**: 68 dos 78 itens com algum problema têm os dois ao mesmo tempo.
Cobertura limpa (moeda válida + produto existente): 285/363 (78.5%).

**Moeda do header ≠ moeda do item, mesmo pedido**: 114/360 pedidos-com-item (31.7%). Dentro de
um pedido os itens usam uma moeda só entre si — a divergência é header vs. item, não item vs.
item. `order_items` não herda moeda de `orders` (herda só a data).
→ join de FX em `int_order_items_enriched` usa `order_items.currency`. Teste customizado conta
a divergência header/item por pedido (baseline: 114).

**`orders.total_amount` vs soma de `order_items`**: 193/360 pedidos-com-item (53.6%) divergem
em mais de 1 centavo. Isolando os pedidos onde header e item currency batem, ainda restam 79
divergências — não é efeito de moeda.
→ `fct_orders` expõe `header_total_usd`, `items_rollup_total_usd` e `has_revenue_discrepancy`,
sem escolher uma fonte.

**`orders.status`**: um valor, `completed`.

**fx_rates**: 2 datas (`2024-06-01`, `2024-09-15`). `order_date` cobre 2024-01-16 a 2024-12-31,
236 dias distintos. 55 pedidos (12%) antes de `2024-06-01`.
→ pedido anterior à primeira data usa a rate de 2024-06-01 (forward-fill); coluna
`fx_rate_source` marca a procedência (`direct`, `inverted`, `forward_filled`).

Rate direta (`base` = a própria moeda) existe para USD e EUR nas duas datas; GBP só tem
`base=GBP` em 2024-06-01. Em 2024-09-15, GBP→USD sai de `base=USD, rates.GBP` invertido.
→ único caso de inversão na tabela; GBP é 4/453 pedidos.

**products.json**: 100 ids, 1–100, sem gap, sem duplicata, 10 categorias × 10 produtos, moeda
sempre USD.

**Sensibilidade do forward-fill no ranking de produto** (top 10 por receita): incluir os 55
pedidos pré-junho troca 2 posições — entram Dashboard Camera HD (id 75) e Car Cleaning Kit
(id 78), saem Tablet Stand Adjustable (id 8) e Leather Ankle Boots (id 15).
