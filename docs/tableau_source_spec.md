# Tableau source spec — "Ecommerce Overview"

**Illustrative, not a real workbook.** No such Tableau workbook exists; this
document is a written stand-in for one, built to look like a typical
mid-complexity Tableau dashboard spec over `thelook_ecommerce`-shaped data,
so that [migration_playbook.md](migration_playbook.md) has something
concrete to translate. It is the source side of the migration this repo
demonstrates — see [../README.md](../README.md) for what the repo actually
proves.

## Data sources

- `order_items` (line-item grain)
- `orders`
- `users`
- `products`
- `inventory_items`

## Calculated fields (8)

| # | Name | Formula (Tableau syntax) | Purpose |
|---|---|---|---|
| 1 | `Revenue` | `SUM([Sale Price])` | Base revenue measure |
| 2 | `Order Count` | `COUNTD([Order ID])` | Distinct orders |
| 3 | `Average Order Value` | `[Revenue] / [Order Count]` | AOV |
| 4 | `Is Returned` | `IF [Status] = "Returned" THEN 1 ELSE 0 END` | Return flag |
| 5 | `Return Rate` | `SUM([Is Returned]) / COUNT([Order Item ID])` | Share of returned line items |
| 6 | `Net Revenue` | `[Revenue] - SUM([Product Cost])` | Revenue after product cost |
| 7 | `Selected Revenue` | `IF [Revenue Metric] = "Net" THEN [Net Revenue] ELSE [Revenue] END` | Parameter-driven KPI tile |
| 8 | `Days Since Order` | `DATEDIFF('day', [Created At], TODAY())` | Recency |

## FIXED LODs (2)

1. **Customer lifetime revenue**
   ```
   { FIXED [Customer ID] : SUM([Sale Price]) }
   ```
   Used to color/filter the customer scatter plot by lifetime value without
   the value changing as the viz is filtered by date or category.

2. **Customer lifetime order count**
   ```
   { FIXED [Customer ID] : COUNTD([Order ID]) }
   ```
   Paired with #1 to classify customers (e.g. "one-time" vs. "repeat")
   independent of the current view's filters.

## Parameter (1)

- **`Revenue Metric`** — string parameter, allowed values `"Gross"` /
  `"Net"`. Drives calculated field #7 so the same KPI tile can show either
  figure without duplicating the sheet.

## Set / group (1)

- **Set: `Repeat Customers`** — defined as customers where the FIXED LOD
  `Customer Lifetime Order Count` ≥ 2. Used as a filter and as a color
  encoding on the customer-level views.

## Table calculation (1)

- **`Month-over-Month Revenue Change`** — `(ZN(SUM([Revenue])) - LOOKUP(ZN(SUM([Revenue])), -1)) / ABS(LOOKUP(ZN(SUM([Revenue])), -1))`, computed along the Month axis of the revenue trend sheet.

## Row-level security rule (1)

- A user filter on `[Customer State]` restricts each sales rep's view to
  their assigned state(s), driven by a published data source's "User
  Filters" entitlement table (one row per Tableau Server user → allowed
  state).

## Extract refresh schedule (1)

- Nightly extract refresh at 03:00 America/New_York, full refresh (no
  incremental), owned by the BI team.
