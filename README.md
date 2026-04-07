# Monitoring DB connections
```bash
#!/usr/bin/env bash

CMD="${1:-}"

THRESHOLD=20
PORT=3306

# -----------------------------
# Build IP → DB name map
# -----------------------------
declare -A DBMAP

while read -r name endpoint; do
  ip=$(getent hosts "$endpoint" | awk '{print $1}' | head -n1)
  if [[ -n "$ip" ]]; then
    DBMAP["$ip"]="$name"
  fi
done < <(aws rds describe-db-instances \
  --query "DBInstances[*].[DBInstanceIdentifier,Endpoint.Address]" \
  --output text 2>/dev/null)

# -----------------------------
# Collect connections
# -----------------------------
get_connections() {
  ss -tn | grep "$PORT" | awk '{print $5}' | cut -d: -f1
}

# -----------------------------
# db top (live view)
# -----------------------------
db_top() {
  echo "🔍 DB TOP (Live View)"
  echo "----------------------------------------"

  TOTAL=$(get_connections | wc -l)
  echo "Total Connections: $TOTAL"
  echo ""

  get_connections | sort | uniq -c | sort -nr | while read count ip; do
    name="${DBMAP[$ip]}"
    name=${name:-UNKNOWN}

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
  TOTAL=$(get_connections | wc -l)

  echo "📊 DB STATS"
  echo "----------------------------------------"
  echo "Total Connections: $TOTAL"
  echo ""

  echo "Top 3 DBs:"
  get_connections | sort | uniq -c | sort -nr | head -n 3 | while read count ip; do
    name="${DBMAP[$ip]}"
    echo "$count → ${name:-UNKNOWN} ($ip)"
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

  get_connections | sort | uniq -c | sort -nr | while read count ip; do
    name="${DBMAP[$ip]}"
    name=${name:-UNKNOWN}

    if (( count > THRESHOLD )); then
      echo "🚨 ALERT: $name ($ip) → $count connections"
      ALERT_FOUND=1
    fi
  done

  if [[ $ALERT_FOUND -eq 0 ]]; then
    echo "✅ All DB connections are within safe limits"
  fi

  echo "----------------------------------------"
}

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