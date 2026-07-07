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
EXIT_PROFILE="$(geo_ip_profile "$HTTP_PROXY_URL" "$GEO_IPINFO_TOKEN")"
EXIT_PROFILE_OK="$(printf '%s\n' "$EXIT_PROFILE" | geo_profile_value ok)"
EXIT_COUNTRY="$(printf '%s\n' "$EXIT_PROFILE" | geo_profile_value countryCode)"
EXIT_TIMEZONE="$(printf '%s\n' "$EXIT_PROFILE" | geo_profile_value timezone)"
LOCALE_BUNDLE="$(geo_locale_bundle "$EXIT_COUNTRY" "$EXIT_TIMEZONE")"
EXPECTED_LANGUAGE="$(printf '%s\n' "$LOCALE_BUNDLE" | geo_profile_value language)"
RUNTIME_PROFILE="$(geo_runtime_profile)"
RUNTIME_ENV_TZ="$(printf '%s\n' "$RUNTIME_PROFILE" | geo_profile_value envTimezone)"
RUNTIME_NODE_TZ="$(printf '%s\n' "$RUNTIME_PROFILE" | geo_profile_value nodeTimezone)"
RUNTIME_TZ="${RUNTIME_ENV_TZ:-$RUNTIME_NODE_TZ}"
RUNTIME_LANG="$(printf '%s\n' "$RUNTIME_PROFILE" | geo_profile_value LANG)"
RUNTIME_LC_ALL="$(printf '%s\n' "$RUNTIME_PROFILE" | geo_profile_value LC_ALL)"
RUNTIME_NODE_LOCALE="$(printf '%s\n' "$RUNTIME_PROFILE" | geo_profile_value nodeDateTimeLocale)"

DIRECT_IP="$(printf '%s\n' "$DIRECT_TRACE" | geo_trace_value ip)"
ENV_IP="$(printf '%s\n' "$ENV_TRACE" | geo_trace_value ip)"
PROXY_IP="$(printf '%s\n' "$PROXY_TRACE" | geo_trace_value ip)"
PROXY_LOC="$(printf '%s\n' "$PROXY_TRACE" | geo_trace_value loc)"
CLAUDE_WEB_LOC="$(printf '%s\n' "$CLAUDE_WEB_TRACE" | geo_trace_value loc)"

if geo_port_open "$GEO_HTTP_PORT"; then
  PORT_OPEN="true"
else
  PORT_OPEN="false"
fi

if [ "$PORT_OPEN" != "true" ]; then
  VERDICT="FAIL: local proxy port is not reachable."
elif [ -z "$PROXY_IP" ]; then
  VERDICT="FAIL: explicit proxy route cannot reach Anthropic trace."
elif [ "$ENV_IP" != "$PROXY_IP" ]; then
  if [ -z "${EFFECTIVE_HTTP_PROXY:-$EFFECTIVE_ALL_PROXY}" ] || [ -z "${EFFECTIVE_HTTPS_PROXY:-$EFFECTIVE_ALL_PROXY}" ]; then
    VERDICT="WARN: explicit proxy works, but Claude Code's terminal env lacks effective HTTP/HTTPS proxy variables."
  else
    VERDICT="WARN: terminal default route does not match explicit proxy route."
  fi
elif [ "$EXIT_PROFILE_OK" = "true" ] && { [ "$RUNTIME_TZ" != "$EXIT_TIMEZONE" ] || ! { geo_locale_matches "$RUNTIME_LANG" "$EXPECTED_LANGUAGE" || geo_locale_matches "$RUNTIME_LC_ALL" "$EXPECTED_LANGUAGE"; }; }; then
  VERDICT="WARN: route matches proxy, but Claude Code runtime timezone/language profile is not aligned with the proxy exit profile."
elif [ "$EXIT_PROFILE_OK" = "true" ]; then
  VERDICT="OK: route and Claude Code runtime timezone/language environment are aligned with the proxy exit profile."
else
  VERDICT="OK: Claude Code terminal egress is consistent with the explicit proxy route."
fi

md_cell() {
  local value="${1:-}"
  [ -n "$value" ] || value="-"
  printf '%s' "$value" | tr '\r\n' ' ' | sed 's/|/\\|/g'
}

trace_field() {
  printf '%s\n' "$1" | geo_trace_value "$2"
}

has_value() {
  if [ -n "${1:-}" ]; then
    printf 'true'
  else
    printf 'false'
  fi
}

printf '## Claude Code Geo Verify (macOS)\n\n'
printf '| Item | Value |\n'
printf '|---|---|\n'
printf '| Expected proxy | %s |\n' "$(md_cell "$HTTP_PROXY_URL")"
printf '| Verdict | %s |\n\n' "$(md_cell "$VERDICT")"

printf '### Checks\n\n'
printf '| Check | Value |\n'
printf '|---|---|\n'
printf '| proxyPortOpen | %s |\n' "$(md_cell "$PORT_OPEN")"
printf '| terminalHttpProxyCovered | %s |\n' "$(md_cell "$(has_value "${EFFECTIVE_HTTP_PROXY:-$EFFECTIVE_ALL_PROXY}")")"
printf '| terminalHttpsProxyCovered | %s |\n' "$(md_cell "$(has_value "${EFFECTIVE_HTTPS_PROXY:-$EFFECTIVE_ALL_PROXY}")")"
printf '| terminalHasAllProxy | %s |\n' "$(md_cell "$(has_value "$EFFECTIVE_ALL_PROXY")")"
printf '| exitProfileDetected | %s |\n' "$(md_cell "$EXIT_PROFILE_OK")"
printf '| exitCountryCode | %s |\n' "$(md_cell "$EXIT_COUNTRY")"
printf '| exitTimezone | %s |\n' "$(md_cell "$EXIT_TIMEZONE")"
printf '| runtimeTimezone | %s |\n' "$(md_cell "$RUNTIME_TZ")"
if [ -n "$EXIT_TIMEZONE" ] && [ "$RUNTIME_TZ" = "$EXIT_TIMEZONE" ]; then
  printf '| timezoneMatchesExit | true |\n'
else
  printf '| timezoneMatchesExit | false |\n'
fi
printf '| expectedLanguage | %s |\n' "$(md_cell "$EXPECTED_LANGUAGE")"
printf '| runtimeLANG | %s |\n' "$(md_cell "$RUNTIME_LANG")"
printf '| runtimeLC_ALL | %s |\n' "$(md_cell "$RUNTIME_LC_ALL")"
if geo_locale_matches "$RUNTIME_LANG" "$EXPECTED_LANGUAGE" || geo_locale_matches "$RUNTIME_LC_ALL" "$EXPECTED_LANGUAGE"; then
  printf '| languageEnvMatchesExit | true |\n'
else
  printf '| languageEnvMatchesExit | false |\n'
fi
printf '| nodeDateTimeLocale | %s |\n' "$(md_cell "$RUNTIME_NODE_LOCALE")"
if geo_locale_matches "$RUNTIME_NODE_LOCALE" "$EXPECTED_LANGUAGE"; then
  printf '| nodeLocaleMatchesExit | true |\n'
else
  printf '| nodeLocaleMatchesExit | false |\n'
fi
printf '| directIp | %s |\n' "$(md_cell "$DIRECT_IP")"
printf '| envIp | %s |\n' "$(md_cell "$ENV_IP")"
printf '| proxyIp | %s |\n' "$(md_cell "$PROXY_IP")"
printf '| proxyLoc | %s |\n' "$(md_cell "$PROXY_LOC")"
printf '| claudeWebProxyLoc | %s |\n\n' "$(md_cell "$CLAUDE_WEB_LOC")"

printf '### Exit IP Profile\n\n'
printf '| Field | Value |\n'
printf '|---|---|\n'
for key in provider ip countryCode country region city timezone isp latitude longitude error; do
  value="$(printf '%s\n' "$EXIT_PROFILE" | geo_profile_value "$key")"
  [ -n "$value" ] && printf '| %s | %s |\n' "$(md_cell "$key")" "$(md_cell "$value")"
done
printf '\n'

printf '### Runtime Profile\n\n'
printf '| Field | Value |\n'
printf '|---|---|\n'
printf '%s\n' "$RUNTIME_PROFILE" | while IFS='=' read -r key value; do
  printf '| %s | %s |\n' "$(md_cell "$key")" "$(md_cell "$value")"
done
printf '\n'

printf '### Inferred Locale Bundle\n\n'
printf '| Field | Value |\n'
printf '|---|---|\n'
printf '%s\n' "$LOCALE_BUNDLE" | while IFS='=' read -r key value; do
  printf '| %s | %s |\n' "$(md_cell "$key")" "$(md_cell "$value")"
done
printf '\n'

printf '### Trace Summary\n\n'
printf '| Route | OK | IP | Location | Colo | Error |\n'
printf '|---|---|---|---|---|---|\n'
for route in DIRECT_TRACE ENV_TRACE PROXY_TRACE CLAUDE_WEB_TRACE; do
  trace="${!route}"
  printf '| %s | %s | %s | %s | %s | %s |\n' \
    "$(md_cell "$route")" \
    "$(md_cell "$(trace_field "$trace" ok)")" \
    "$(md_cell "$(trace_field "$trace" ip)")" \
    "$(md_cell "$(trace_field "$trace" loc)")" \
    "$(md_cell "$(trace_field "$trace" colo)")" \
    "$(md_cell "$(trace_field "$trace" error)")"
done
