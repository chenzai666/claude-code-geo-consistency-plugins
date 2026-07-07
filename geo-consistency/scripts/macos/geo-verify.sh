#!/usr/bin/env bash

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=geo-common.sh
. "${SCRIPT_DIR}/geo-common.sh"

geo_parse_args "$@" || exit $?

HTTP_PROXY_URL="$(geo_http_proxy)"
TARGET="https://api.anthropic.com/cdn-cgi/trace"
EFFECTIVE_HTTP_PROXY="${HTTP_PROXY:-${http_proxy:-}}"
EFFECTIVE_HTTPS_PROXY="${HTTPS_PROXY:-${https_proxy:-}}"
EFFECTIVE_ALL_PROXY="${ALL_PROXY:-${all_proxy:-}}"

DIRECT_TRACE="$(geo_trace "forced-direct" "$TARGET")"
ENV_TRACE="$(geo_trace "env-default" "$TARGET")"
PROXY_TRACE="$(geo_trace "explicit-proxy" "$TARGET" "$HTTP_PROXY_URL")"
CLAUDE_WEB_TRACE="$(geo_trace "claude-web-proxy" "https://claude.ai/cdn-cgi/trace" "$HTTP_PROXY_URL")"

DIRECT_IP="$(printf '%s\n' "$DIRECT_TRACE" | geo_trace_value ip)"
ENV_IP="$(printf '%s\n' "$ENV_TRACE" | geo_trace_value ip)"
PROXY_IP="$(printf '%s\n' "$PROXY_TRACE" | geo_trace_value ip)"
PROXY_LOC="$(printf '%s\n' "$PROXY_TRACE" | geo_trace_value loc)"
CLAUDE_WEB_LOC="$(printf '%s\n' "$CLAUDE_WEB_TRACE" | geo_trace_value loc)"

geo_section "Claude Code Geo Verify (macOS)"
geo_kv "Expected proxy" "$HTTP_PROXY_URL"

geo_section "Checks"
if geo_port_open "$GEO_HTTP_PORT"; then
  PORT_OPEN="true"
else
  PORT_OPEN="false"
fi
geo_kv "proxyPortOpen" "$PORT_OPEN"
geo_kv "terminalHasHttpProxy" "${EFFECTIVE_HTTP_PROXY:+true}"
geo_kv "terminalHasHttpsProxy" "${EFFECTIVE_HTTPS_PROXY:+true}"
geo_kv "terminalHasAllProxy" "${EFFECTIVE_ALL_PROXY:+true}"
geo_kv "directIp" "$DIRECT_IP"
geo_kv "envIp" "$ENV_IP"
geo_kv "proxyIp" "$PROXY_IP"
geo_kv "proxyLoc" "$PROXY_LOC"
geo_kv "claudeWebProxyLoc" "$CLAUDE_WEB_LOC"

geo_section "Trace Summary"
printf '%s\n\n%s\n\n%s\n\n%s\n' "$DIRECT_TRACE" "$ENV_TRACE" "$PROXY_TRACE" "$CLAUDE_WEB_TRACE"

geo_section "Verdict"
if [ "$PORT_OPEN" != "true" ]; then
  echo "FAIL: local proxy port is not reachable."
elif [ -z "$PROXY_IP" ]; then
  echo "FAIL: explicit proxy route cannot reach Anthropic trace."
elif [ "$ENV_IP" != "$PROXY_IP" ]; then
  if [ -z "$EFFECTIVE_HTTP_PROXY" ] || [ -z "$EFFECTIVE_HTTPS_PROXY" ]; then
    echo "WARN: explicit proxy works, but Claude Code's terminal env lacks effective HTTP/HTTPS proxy variables."
  else
    echo "WARN: terminal default route does not match explicit proxy route."
  fi
else
  echo "OK: Claude Code terminal egress is consistent with the explicit proxy route."
fi
