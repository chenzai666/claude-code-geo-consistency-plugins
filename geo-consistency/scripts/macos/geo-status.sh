#!/usr/bin/env bash

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=geo-common.sh
. "${SCRIPT_DIR}/geo-common.sh"

geo_parse_args "$@" || exit $?

HTTP_PROXY_URL="$(geo_http_proxy)"
SOCKS_PROXY_URL="$(geo_socks_proxy)"

geo_section "Claude Code Geo Status (macOS)"
geo_kv "Expected HTTP proxy" "$HTTP_PROXY_URL"
geo_kv "Expected SOCKS proxy" "$SOCKS_PROXY_URL"

if geo_port_open "$GEO_HTTP_PORT"; then
  geo_kv "HTTP port open" "true"
else
  geo_kv "HTTP port open" "false"
fi

if geo_port_open "$GEO_SOCKS_PORT"; then
  geo_kv "SOCKS port open" "true"
else
  geo_kv "SOCKS port open" "false"
fi

geo_section "Process Environment"
geo_print_env

geo_section "macOS System Proxy"
if command -v scutil >/dev/null 2>&1; then
  scutil --proxy
else
  geo_kv "scutil" "not found"
fi

geo_section "Tool Proxy Config"
geo_print_tool_config

if [ "$GEO_SKIP_NETWORK" != "1" ]; then
  geo_section "Egress Traces"
  geo_trace "env-default" "https://api.anthropic.com/cdn-cgi/trace"
  printf '\n'
  geo_trace "env-default" "https://claude.ai/cdn-cgi/trace"
  printf '\n'
  geo_trace "explicit-proxy" "https://cloudflare.com/cdn-cgi/trace" "$HTTP_PROXY_URL"
else
  printf '\nTip: status is local-only by default. Use --include-network to add egress traces.\n'
fi
