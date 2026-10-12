# Migration playbook: Tableau → Looker

Maps every construct in [tableau_source_spec.md](tableau_source_spec.md) to
its LookML equivalent in this repo, notes what doesn't map cleanly, and
explains why this direction of migration is harder than the reverse.

## Construct-by-construct mapping

| Tableau construct | LookML equivalent | File | Clean 1:1? |
|---|---|---|---|
| Calc field `Revenue` | `measure: total_revenue` | [order_items.view.lkml](../views/order_items.view.lkml) | Yes |
| Calc field `Order Count` | `measure: order_count` (count_distinct) | [order_items.view.lkml](../views/order_items.view.lkml) | Yes |
| Calc field `Average Order Value` | `measure: average_order_value` | [order_items.view.lkml](../views/order_items.view.lkml) | Yes |
| Calc field `Is Returned` | `dimension: is_returned` | [order_items.view.lkml](../views/order_items.view.lkml) | Yes |
| Calc field `Return Rate` | `measure: return_rate` | [order_items.view.lkml](../views/order_items.view.lkml) | Yes |
| Calc field `Net Revenue` | `measure: total_net_revenue` | [order_items_refinement.view.lkml](../views/order_items_refinement.view.lkml) | Yes, but only inside an explore that joins `products` — remove that join and the measure breaks |
| Calc field `Selected Revenue` | `measure: selected_revenue` (Liquid branches on the parameter) | [order_items_refinement.view.lkml](../views/order_items_refinement.view.lkml) | Mostly — LookML Liquid conditionals on a parameter are more verbose than a Tableau `IF` calc |
| Calc field `Days Since Order` | *(not built)* | — | ⚠ Doesn't map cleanly, see below |
| FIXED LOD: lifetime revenue | `customer_lifetime_value` derived table, joined 1:1 to `users` | [customer_lifetime_value.view.lkml](../views/customer_lifetime_value.view.lkml) | Yes, but the mechanism is different (pre-aggregated join, not a query-time scoped aggregation) |
| FIXED LOD: lifetime order count | Same derived table, `lifetime_order_count` dimension | [customer_lifetime_value.view.lkml](../views/customer_lifetime_value.view.lkml) | Yes, same caveat |
| Parameter `Revenue Metric` | `parameter: revenue_metric` | [order_items_refinement.view.lkml](../views/order_items_refinement.view.lkml) | Yes |
| Set `Repeat Customers` | `dimension` on `customer_lifetime_value.lifetime_order_count >= 2`, used as a filter | *(not built — see below)* | ⚠ Partial — Looker has no first-class "set" object; the closest equivalent is a derived dimension or an `access_grant`-style filter |
| Table calc: MoM revenue change | *(not built)* | — | ⚠ Doesn't map cleanly, see below |
| Row-level security (user filter on state) | `access_filter` on the `order_items` explore, keyed to a `state` user attribute | [ecommerce.model.lkml](../models/ecommerce.model.lkml) | Yes, but enforcement model is different — see below |
| Extract refresh schedule | `datagroup` + `persist_with` (cache TTL trigger) | [ecommerce.model.lkml](../models/ecommerce.model.lkml) | Partial — a Looker datagroup controls *cache* invalidation against a live connection; it is not a scheduled extract rebuild |

## What doesn't map cleanly, and why

- **`Days Since Order`** — a row-level calc against `TODAY()`. LookML has no
  direct `TODAY()` equivalent inside a `sql:` expression; it would need a
  dialect-specific function (e.g. `CURRENT_DATE()` in BigQuery SQL) baked
  into the dimension's `sql:` parameter. Left out here rather than guessed
  at, per this repo's rule against unverified LookML.
- **Table calculation (MoM revenue change)** — Tableau table calcs operate
  on the rendered table/viz itself (partition + addressing). Looker has no
  direct equivalent; the nearest options are (a) a custom SQL window
  function pushed into a derived table, which changes the query's grain and
  has to be designed per-report, or (b) a Looker "table calculation" field
  defined *in the Explore UI*, which lives in the query, not in LookML, and
  so isn't portable/version-controlled the way everything else in this repo
  is. Neither is a drop-in replacement — this is one of the real migration
  costs, not a documentation gap.
- **Sets** — Tableau sets are reusable, UI-managed membership lists.
  LookML has no first-class set object; the usual substitute is a SQL
  `CASE`/boolean dimension (as noted in the table above), which loses the
  "editable list of members" workflow Tableau authors are used to.
- **FIXED LOD → derived table join** — behaviorally similar, but the
  *mechanism* differs: a Tableau FIXED LOD is recomputed by the query engine
  at render time inside each sheet's filter context; a LookML derived table
  is a separate pre-aggregated query that gets joined in. If the join
  (`relationship: many_to_one`, one row per customer) is set up correctly,
  results match, but a Looker developer who writes the join as `one_to_one`
  or fans it out incorrectly will silently get wrong totals — the FIXED LOD
  has no such failure mode in Tableau because the aggregation scope is
  declared on the calc itself, not on a join.
- **Row-level security** — Tableau's user-filter approach ties security to
  a published data source's entitlement table at *query* time, scoped per
  sheet/workbook. Looker's `access_filter` is declared once on the explore
  and is enforced for every query against it, driven by a *user attribute*
  set on the Looker user/group — the entitlement lives in the identity
  layer, not a data table joined into the query. Functionally similar
  outcome (same rows filtered), different enforcement point and different
  place the entitlement data has to live.
- **Extract refresh → datagroup** — a Tableau extract schedule rebuilds a
  materialized copy of the data. A Looker datagroup only controls how long
  Looker's query cache is trusted before re-querying the live connection;
  it does not materialize anything itself. If the underlying warehouse
  table only updates nightly, that's the real "freshness" boundary — the
  datagroup should be set to match it, not treated as its own refresh job.

## Why Tableau → Looker is harder than the reverse

Going from a LookML semantic layer to Tableau workbooks is comparatively
mechanical: the business logic already lives in one place (the LookML
model), and building a workbook against it means pointing Tableau's live
connection or extract at it and laying out visuals — the hard thinking is
already done.

Going the other way starts from scattered logic, not a shared model. In a
typical Tableau estate, the same "Revenue" calc gets re-created, slightly
differently, in a dozen workbooks — one has a stray filter baked in,
another used `SUM` where a sibling used `AVG`, a third hardcoded a currency
assumption. There is no single source of truth to read off; the semantic
layer has to be *reconstructed* by diffing many workbooks' calc fields
against each other, deciding which (if any) is "correct," and only then
can a LookML model be written. This repo's `order_items.view.lkml` measures
look simple because they were designed fresh, in one place — a real
migration spends most of its time *before* that point, reconciling
divergent definitions.

### Recommended approach

1. **Model the semantic layer first, before touching dashboards.** Agree on
   one definition per metric (revenue, order count, AOV, return rate) and
   get it into LookML views, independent of any specific dashboard. Every
   dashboard then consumes the same measures — the opposite of how the
   Tableau estate likely got into its current state.
2. **Migrate in small batches**, one workbook (or one closely-related
   group of sheets) at a time, rather than attempting a big-bang cutover.
   Each batch should be small enough that a mismatch is traceable to a
   specific calc or join.
3. **Run Looker and Tableau in parallel** for each migrated
   dashboard/report for at least one full reporting cycle before retiring
   the Tableau version, so stakeholders can sanity-check numbers against
   something they already trust.
4. **Automate reconciliation tests** (the kind of thing
   [tools/check_lookml.py](../tools/check_lookml.py) does for structural
   correctness, but for *numbers*): a scheduled query that runs the
   equivalent metric through both Tableau's extract/live connection and the
   new LookML explore and flags any delta beyond a small tolerance. Catching
   a silent mismatch (e.g. a LOD-to-join grain error) this way is far
   cheaper than catching it from a confused stakeholder three weeks after
   cutover.
