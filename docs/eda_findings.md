# EDA - achados nos dados brutos

Análise feita direto sobre `data/raw/*` via DuckDB, antes de qualquer ingestão ou modelo dbt.
Script em `eda/explore_raw.py`, roda em segundos e reproduz todos os números abaixo.

## Volume

| arquivo | linhas |
|---|---|
| customers.csv | 50 |
| orders.csv | 453 |
| order_items.csv | 363 |
| products.json | 100 |
| fx_rates.json | 5 respostas em `responses[]` (mais um `error_example`, que não é um rate) |

Chaves (`id`) são únicas em orders, order_items e customers. Sem duplicata.

## Pedidos sem item

93 dos 453 pedidos (20.5%) não têm nenhuma linha em order_items. Isso limita direto a
cobertura de qualquer ranking de produto no grão de item: 1 em cada 5 pedidos não entra.

## Moeda inválida

`orders.currency` e `order_items.currency` têm três códigos que não existem na ISO 4217:
`ABC`, `XYZ`, `QWE`. Em orders são 79/453 (17.4%); em order_items, 75/363 (20.7%).
Só aparecem a partir de agosto/2024 - antes disso, moeda é sempre USD/EUR/GBP.

## Produto órfão

71 dos 363 itens (19.6%) referenciam `product_id` que não existe em products.json.
São exatamente os ids 101 a 110 - dez ids seguidos, logo depois do catálogo (que vai até
100). Tem cara de dado injetado de propósito pro exercício, não de drift real de catálogo.

Os dois problemas (moeda inválida e produto órfão) se sobrepõem bastante: das linhas com
algum problema, a maioria tem os dois ao mesmo tempo. Cobertura "limpa" (moeda válida e
produto existente) fica em 285/363 itens, 78.5%.

## Moeda do pedido != moeda dos itens

Achado que não estava nas premissas iniciais: em 114 dos 360 pedidos que têm item (31.7%),
a moeda do header (`orders.currency`) é diferente da moeda dos itens (`order_items.currency`).
Dentro de um mesmo pedido os itens sempre usam uma moeda só entre si - o problema é
header vs. item, não item vs. item.

Isso importa porque order_items **não herda a moeda do pedido**, só herda a data (não tem
coluna de data própria). Juntar FX pela moeda do header, por analogia com a data, dá conversão
errada em quase um terço dos pedidos.

## total_amount não bate com a soma dos itens

Outro achado fora das premissas iniciais: `orders.total_amount` diverge da soma de
`quantity * unit_price` dos itens em 193 dos 360 pedidos com item (53.6%). Não é
arredondamento - as diferenças chegam a quase 3x o valor. E não é só efeito da moeda:
mesmo nos pedidos onde header e item currency batem, ainda tem 79 casos de divergência.

Não dá pra tratar `total_amount` como fonte única de verdade de receita do pedido, nem
recalcular tudo a partir dos itens sem documentar que os dois números vão discordar.

## status

`orders.status` tem um único valor: `completed`. Não existe pedido cancelado ou pendente
nesse dataset.

## fx_rates

Só duas datas no arquivo: `2024-06-01` e `2024-09-15`. Os pedidos cobrem o ano inteiro
(16/jan a 31/dez, 236 dias distintos). 55 pedidos (12%) são anteriores à primeira data de
fx - não tem rate passada pra usar, então "backfill" não é a palavra certa; é forward-fill
mesmo (usar a taxa de junho pra pedido de janeiro).

Rate direta (`base` = a própria moeda, convertendo pra USD) existe para USD e EUR nas duas
datas, mas GBP só tem `base=GBP` em junho - em setembro, GBP->USD só sai invertendo a rate
`base=USD, rates.GBP`. Único caso de inversão em toda a tabela; GBP é só 4 pedidos.

## produtos

products.json não tem nenhum problema: 100 ids de 1 a 100, sem gap, sem duplicata, 10
categorias com 10 produtos cada, moeda sempre USD. Toda a sujeira do dataset está do lado
transacional (orders/order_items), não no catálogo.

## decisões que saem direto desses números

- `fct_orders` expõe `header_total_usd` e `items_rollup_total_usd` separados, com
  `has_revenue_discrepancy` - não escolhe uma fonte silenciosamente.
- Moeda sem rate disponível -> `revenue_usd` null, linha continua no fato, flagada. Conta
  pra volume, não pra receita.
- Pedido antes de `2024-06-01` usa a taxa de junho (forward-fill), com uma coluna
  `fx_rate_source` marcando de onde veio a taxa.
- Join de FX em `order_items` usa `order_items.currency`, nunca `orders.currency`.
- Ranking de produto usa toda linha com receita convertível; produto órfão aparece como
  "Unknown" via membro desconhecido em `dim_products`.

Testado o efeito do forward-fill no ranking: incluir os 55 pedidos pré-junho troca 2 dos
10 produtos no top 10 (entram Dashboard Camera HD e Car Cleaning Kit, saem Tablet Stand
Adjustable e Leather Ankle Boots). Não é um detalhe cosmético - vale deixar visível no
dashboard que o ranking depende dessa escolha.
