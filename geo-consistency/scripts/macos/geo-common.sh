#!/usr/bin/env bash

set -u

geo_parse_args() {
  GEO_PROXY_HOST="127.0.0.1"
  GEO_HTTP_PORT="10808"
  GEO_SOCKS_PORT="10808"
  GEO_RC_FILE="${HOME}/.zshrc"
  GEO_JSON="0"
  GEO_SKIP_NETWORK="1"

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --proxy-host)
        GEO_PROXY_HOST="$2"; shift 2 ;;
      --http-port)
        GEO_HTTP_PORT="$2"; shift 2 ;;
      --socks-port)
        GEO_SOCKS_PORT="$2"; shift 2 ;;
      --rc-file)
        GEO_RC_FILE="$2"; shift 2 ;;
      --json)
        GEO_JSON="1"; shift ;;
      --skip-network)
        GEO_SKIP_NETWORK="1"; shift ;;
      --include-network)
        GEO_SKIP_NETWORK="0"; shift ;;
      *)
        echo "Unknown argument: $1" >&2; return 2 ;;
    esac
  done
}

geo_http_proxy() {
  printf 'http://%s:%s' "$GEO_PROXY_HOST" "$GEO_HTTP_PORT"
}

geo_socks_proxy() {
  printf 'socks5://%s:%s' "$GEO_PROXY_HOST" "$GEO_SOCKS_PORT"
}

geo_port_open() {
  if command -v nc >/dev/null 2>&1; then
    nc -z -G 1 "$GEO_PROXY_HOST" "$1" >/dev/null 2>&1
    return $?
  fi
  return 2
}

geo_trace() {
  local route="$1"
  local url="$2"
  local proxy="${3:-}"
  local args=(-fsS --connect-timeout 5 --max-time 12)

  if [ "$route" = "forced-direct" ]; then
    args+=(--noproxy '*')
  fi
  if [ -n "$proxy" ]; then
    args+=(--proxy "$proxy")
  fi

  local out
  if ! out=$(curl "${args[@]}" "$url" 2>&1); then
    printf 'route=%s\nurl=%s\nok=false\nerror=%s\n' "$route" "$url" "$out"
    return 0
  fi

  printf 'route=%s\nurl=%s\nok=true\n%s\n' "$route" "$url" "$out"
}

geo_trace_value() {
  local key="$1"
  awk -F= -v k="$key" '$1 == k { print substr($0, length(k) + 2); exit }'
}

geo_section() {
  printf '\n== %s ==\n' "$1"
}

geo_kv() {
  local value="${2:-}"
  [ -n "$value" ] || value="-"
  printf '%-24s %s\n' "$1:" "$value"
}

geo_print_env() {
  for name in HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY http_proxy https_proxy all_proxy no_proxy ANTHROPIC_BASE_URL TZ LANG LC_ALL; do
    eval "value=\${$name-}"
    geo_kv "$name" "$value"
  done
}

geo_print_tool_config() {
  if command -v git >/dev/null 2>&1; then
    geo_kv "git http.proxy" "$(git config --global --get http.proxy 2>/dev/null || true)"
    geo_kv "git https.proxy" "$(git config --global --get https.proxy 2>/dev/null || true)"
  else
    geo_kv "git" "not found"
  fi

  if command -v npm >/dev/null 2>&1; then
    geo_kv "npm proxy" "$(npm config get proxy 2>/dev/null || true)"
    geo_kv "npm https-proxy" "$(npm config get https-proxy 2>/dev/null || true)"
  else
    geo_kv "npm" "not found"
  fi
}
