# Derived table that replaces a Tableau FIXED LOD:
#   { FIXED [Customer ID] : SUM([Revenue]) }
#   { FIXED [Customer ID] : COUNTD([Order ID]) }
# In Tableau, the FIXED aggregation is computed at query time, inside the
# viz's own context, independent of the sheet's filters/grain. In LookML the
# same "aggregate independent of query grain" need is met by pre-aggregating
# to the customer grain in a derived table, then joining it back (see
# models/ecommerce.model.lkml): joined to order_items on user_id,
# relationship: many_to_one -- one row here per customer. The join gives
# every explore a stable lifetime_revenue/lifetime_order_count value per
# customer regardless of what the query is sliced or filtered by.

view: customer_lifetime_value {
  derived_table: {
    sql:
      SELECT
        user_id,
        COUNT(DISTINCT order_id) AS lifetime_order_count,
        SUM(sale_price) AS lifetime_revenue
      FROM ${order_items.SQL_TABLE_NAME}
      GROUP BY 1
    ;;
  }

  dimension: user_id {
    type: number
    primary_key: yes
    hidden: yes
    sql: ${TABLE}.user_id ;;
  }

  dimension: lifetime_order_count {
    type: number
    sql: ${TABLE}.lifetime_order_count ;;
  }

  dimension: lifetime_revenue {
    type: number
    value_format_name: usd
    sql: ${TABLE}.lifetime_revenue ;;
  }

  # Tableau set `Repeat Customers`: { FIXED [Customer ID] : COUNTD([Order ID]) } >= 2.
  # LookML has no editable-membership "set" object like Tableau's -- this
  # yes/no dimension captures the membership *rule*, but not the "open the
  # set, see/edit who's in it" UI workflow Tableau authors get for free.
  dimension: is_repeat_customer {
    type: yesno
    sql: ${lifetime_order_count} >= 2 ;;
  }

  measure: average_lifetime_revenue {
    type: average
    sql: ${lifetime_revenue} ;;
    value_format_name: usd
  }
}
