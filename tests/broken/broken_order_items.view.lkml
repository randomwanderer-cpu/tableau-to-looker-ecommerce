# Deliberately broken fixture for tests/test_checker.py.
# Each dimension/measure below trips a different rule in tools/check_lookml.py:
#   - no primary_key: yes anywhere in this view            -> rule 4
#   - "sql_price" duplicated under dimensions twice         -> rule 3
#   - "total" references a field that doesn't exist         -> rule 1 (same-view)
#   - "bad_join" (added separately in broken_model.model.lkml) references
#     an unknown view                                        -> rule 2

view: broken_order_items {
  dimension: sql_price {
    type: number
    sql: ${TABLE}.sale_price ;;
  }

  dimension: sql_price {
    type: number
    sql: ${TABLE}.sale_price * 2 ;;
  }

  measure: total {
    type: sum
    sql: ${sale_price_that_does_not_exist} ;;
  }
}
