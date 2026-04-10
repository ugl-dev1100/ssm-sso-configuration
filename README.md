# Monitoring DB connections
```bash
  #!/usr/bin/env bash

CMD="${1:-}"

THRESHOLD=20
PORT=3306

# -----------------------------
# Build IP → DB name map (optional file-based)
# -----------------------------
declare -A DBMAP

build_db_map() {
  MAP_FILE="$HOME/.rds-map"

  [[ ! -f "$MAP_FILE" ]] && return

  while read -r ip name; do
    [[ -z "$ip" || -z "$name" ]] && continue
    DBMAP["$ip"]="$name"
  done < "$MAP_FILE"
}

# -----------------------------
# Resolve DB name
# -----------------------------
resolve_name() {
  local ip="$1"

  [[ -z "$ip" ]] && echo "UNKNOWN" && return

  local name="${DBMAP[$ip]}"

  if [[ -z "$name" ]]; then
    reverse=$(getent hosts "$ip" | awk '{print $2}')
    name=${reverse:-UNKNOWN}
  fi

  echo "$name"
}

# -----------------------------
# Collect ONLY real connections
# -----------------------------
get_connections() {
  ss -tn \
    | awk -v port=":$PORT" '
      $1 == "ESTAB" && $5 ~ port {
        split($5, a, ":")
        print a[1]
      }'
}

# -----------------------------
# db top (live view)
# -----------------------------
db_top() {
  echo "🔍 DB TOP (Live View)"
  echo "----------------------------------------"

  connections=$(get_connections)

  TOTAL=$(echo "$connections" | grep -c .)

  echo "Total Connections: $TOTAL"
  echo ""

  echo "$connections" | grep . | sort | uniq -c | sort -nr | while read -r count ip; do
    name=$(resolve_name "$ip")

    if (( count > THRESHOLD )); then
      echo "🚨 $count → $name ($ip)"
    else
      echo "   $count → $name ($ip)"
    fi
  done

  echo "----------------------------------------"
}

# -----------------------------
# db stats (summary)
# -----------------------------
db_stats() {
  connections=$(get_connections)

  TOTAL=$(echo "$connections" | grep -c .)

  echo "📊 DB STATS"
  echo "----------------------------------------"
  echo "Total Connections: $TOTAL"
  echo ""

  echo "Top 3 DBs:"
  echo "$connections" | grep . | sort | uniq -c | sort -nr | head -n 3 | while read -r count ip; do
    name=$(resolve_name "$ip")
    echo "$count → $name ($ip)"
  done

  echo "----------------------------------------"
}

# -----------------------------
# db alert (threshold check)
# -----------------------------
db_alert() {
  echo "🚨 DB ALERT CHECK"
  echo "----------------------------------------"

  ALERT_FOUND=0

  while read -r count ip; do
    [[ -z "$ip" ]] && continue

    name=$(resolve_name "$ip")

    if (( count > THRESHOLD )); then
      echo "🚨 ALERT: $name ($ip) → $count connections"
      ALERT_FOUND=1
    fi
  done < <(get_connections | grep . | sort | uniq -c | sort -nr)

  if [[ $ALERT_FOUND -eq 0 ]]; then
    echo "✅ All DB connections are within safe limits"
  fi

  echo "----------------------------------------"
}

# -----------------------------
# Init
# -----------------------------
build_db_map

# -----------------------------
# Command handler
# -----------------------------
case "$CMD" in
  top)
    db_top
    ;;
  stats)
    db_stats
    ;;
  alert)
    db_alert
    ;;
  *)
    echo "Usage: db {top|stats|alert}"
    ;;
esac
  ```
  1. chmod +x db
  2. sudo mv db /usr/loca/bin/
  3. db top
  4. db stats
  5. db alert