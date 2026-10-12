# Refinement (+view) of order_items.
# Mirrors a Tableau parameter that lets a dashboard viewer toggle a KPI tile
# between two measure definitions without duplicating the tile.

view: +order_items {

  parameter: revenue_metric {
    type: unquoted
    allowed_value: { label: "Gross Revenue" value: "gross" }
    allowed_value: { label: "Net Revenue (after product cost)" value: "net" }
  }

  measure: total_net_revenue {
    type: sum
    sql: ${TABLE}.sale_price - ${products.cost} ;;
    value_format_name: usd
  }

  measure: selected_revenue {
    type: number
    sql:
      {% if revenue_metric._parameter_value == 'net' %}
        ${total_net_revenue}
      {% else %}
        ${total_revenue}
      {% endif %} ;;
    value_format_name: usd
  }
}
