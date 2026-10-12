# Deliberately broken fixture for tests/test_checker.py.
# "ghost_view" does not exist anywhere in this project -> rule 2.

explore: broken_order_items {
  join: ghost_view {
    type: left_outer
    sql_on: ${broken_order_items.sql_price} = ${ghost_view.id} ;;
    relationship: many_to_one
  }
}
