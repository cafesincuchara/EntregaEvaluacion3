#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://productosapi-alb-1646067421.us-east-1.elb.amazonaws.com/api/v1/products}"

usage() {
  cat <<EOF
Uso: $0 <comando> [args]

Comandos:
  list                     GET todos los productos
  get <id>                 GET producto por UUID
  create <name> <price>    POST nuevo producto (abre editor para el JSON)
  update <id>              PUT actualizar producto (abre editor)
  delete <id>              DELETE producto
  help                     Muestra este mensaje

Variables de entorno:
  BASE_URL  URL base (default: $BASE_URL)
EOF
}

list() {
  curl -sf "$BASE_URL" | jq .
}

get() {
  local id="$1"
  curl -sf "$BASE_URL/$id" | jq .
}

create() {
  local name="${1:-Nombre}" price="${2:-0}"
  local tmpfile
  tmpfile=$(mktemp)
  cat > "$tmpfile" <<JSON
{
  "name": "$name",
  "description": "Descripcion del producto",
  "price": $price,
  "category": "General",
  "stock": 10
}
JSON
  "${EDITOR:-vi}" "$tmpfile"
  echo "--- POST $BASE_URL ---"
  curl -sf -X POST "$BASE_URL" \
    -H "Content-Type: application/json" \
    -d @"$tmpfile" | jq .
  rm -f "$tmpfile"
}

update() {
  local id="$1"
  local tmpfile
  tmpfile=$(mktemp)
  curl -sf "$BASE_URL/$id" | jq . > "$tmpfile"
  echo "Editando producto (actual: $(cat "$tmpfile" | jq -c .))"
  "${EDITOR:-vi}" "$tmpfile"
  echo "--- PUT $BASE_URL/$id ---"
  curl -sf -X PUT "$BASE_URL/$id" \
    -H "Content-Type: application/json" \
    -d @"$tmpfile" | jq .
  rm -f "$tmpfile"
}

delete() {
  local id="$1"
  echo "--- DELETE $BASE_URL/$id ---"
  curl -sf -X DELETE "$BASE_URL/$id" -w "\nHTTP %{http_code}\n" | jq . || echo "Eliminado (204 No Content)"
}

cmd="${1:-help}"
shift 2>/dev/null || true

case "$cmd" in
  list)   list "$@" ;;
  get)    get "${1:?Falta id}" ;;
  create) create "${1:-}" "${2:-}" ;;
  update) update "${1:?Falta id}" ;;
  delete) delete "${1:?Falta id}" ;;
  help|*) usage ;;
esac
