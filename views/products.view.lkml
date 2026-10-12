view: products {
  sql_table_name: `bigquery-public-data.thelook_ecommerce.products` ;;

  dimension: id {
    type: number
    primary_key: yes
    sql: ${TABLE}.id ;;
  }

  dimension: name {
    type: string
    sql: ${TABLE}.name ;;
  }

  dimension: brand {
    type: string
    sql: ${TABLE}.brand ;;
  }

  dimension: category {
    type: string
    sql: ${TABLE}.category ;;
  }

  dimension: department {
    type: string
    sql: ${TABLE}.department ;;
  }

  dimension: sku {
    type: string
    sql: ${TABLE}.sku ;;
  }

  dimension: distribution_center_id {
    type: number
    hidden: yes
    sql: ${TABLE}.distribution_center_id ;;
  }

  dimension: cost {
    type: number
    value_format_name: usd
    sql: ${TABLE}.cost ;;
  }

  dimension: retail_price {
    type: number
    value_format_name: usd
    sql: ${TABLE}.retail_price ;;
  }

  measure: count {
    type: count
    drill_fields: [id, name, brand, category]
  }

  measure: average_retail_price {
    type: average
    sql: ${retail_price} ;;
    value_format_name: usd
  }
}
