#!/usr/bin/env bash

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=geo-common.sh
. "${SCRIPT_DIR}/geo-common.sh"

GEO_PRINT_ONLY="0"
GEO_CLAUDE_COMMAND="claude"
CLAUDE_ARGS=()
PARSE_ARGS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --proxy-host|--http-port|--socks-port|--rc-file|--ipinfo-token)
      PARSE_ARGS+=("$1" "$2"); shift 2 ;;
    --claude-command)
      GEO_CLAUDE_COMMAND="$2"; shift 2 ;;
    --print-only)
      GEO_PRINT_ONLY="1"; shift ;;
    --)
      shift
      CLAUDE_ARGS=("$@")
      break ;;
    *)
      CLAUDE_ARGS+=("$1"); shift ;;
  esac
done

geo_parse_args "${PARSE_ARGS[@]}" || exit $?

HTTP_PROXY_URL="$(geo_http_proxy)"
SOCKS_PROXY_URL="$(geo_socks_proxy)"
EXIT_PROFILE="$(geo_ip_profile "$HTTP_PROXY_URL" "$GEO_IPINFO_TOKEN")"
EXIT_PROFILE_OK="$(printf '%s\n' "$EXIT_PROFILE" | geo_profile_value ok)"

if [ "$EXIT_PROFILE_OK" != "true" ]; then
  printf 'Could not detect proxy exit profile: %s\n' "$(printf '%s\n' "$EXIT_PROFILE" | geo_profile_value error)" >&2
  exit 1
fi

EXIT_COUNTRY="$(printf '%s\n' "$EXIT_PROFILE" | geo_profile_value countryCode)"
EXIT_TIMEZONE="$(printf '%s\n' "$EXIT_PROFILE" | geo_profile_value timezone)"
LOCALE_BUNDLE="$(geo_locale_bundle "$EXIT_COUNTRY" "$EXIT_TIMEZONE")"
LANGUAGE_TAG="$(printf '%s\n' "$LOCALE_BUNDLE" | geo_profile_value language)"
POSIX_LOCALE="$(printf '%s\n' "$LOCALE_BUNDLE" | geo_profile_value posixLocale)"
ACCEPT_LANGUAGE="$(printf '%s\n' "$LOCALE_BUNDLE" | geo_profile_value acceptLanguage)"
NO_PROXY_VALUE="${NO_PROXY:-${no_proxy:-localhost,127.0.0.1,::1}}"

printf '## Claude Code Geo Launch Profile\n\n'
printf '| Field | Value |\n'
printf '|---|---|\n'
printf '| exitProvider | %s |\n' "$(printf '%s\n' "$EXIT_PROFILE" | geo_profile_value provider)"
printf '| exitIp | %s |\n' "$(printf '%s\n' "$EXIT_PROFILE" | geo_profile_value ip)"
printf '| exitLocation | %s / %s / %s |\n' "$EXIT_COUNTRY" "$(printf '%s\n' "$EXIT_PROFILE" | geo_profile_value region)" "$(printf '%s\n' "$EXIT_PROFILE" | geo_profile_value city)"
printf '| exitTimezone | %s |\n' "$EXIT_TIMEZONE"
printf '| language | %s |\n' "$LANGUAGE_TAG"
printf '| posixLocale | %s |\n' "$POSIX_LOCALE"
printf '| acceptLanguage | %s |\n\n' "$ACCEPT_LANGUAGE"

printf '### Applied Process Environment\n\n'
printf '| Name | Value |\n'
printf '|---|---|\n'
printf '| HTTP_PROXY | %s |\n' "$HTTP_PROXY_URL"
printf '| HTTPS_PROXY | %s |\n' "$HTTP_PROXY_URL"
printf '| ALL_PROXY | %s |\n' "$SOCKS_PROXY_URL"
printf '| NO_PROXY | %s |\n' "$NO_PROXY_VALUE"
printf '| TZ | %s |\n' "$EXIT_TIMEZONE"
printf '| LANG | %s |\n' "$POSIX_LOCALE"
printf '| LC_ALL | %s |\n' "$POSIX_LOCALE"
printf '| LC_MESSAGES | %s |\n' "$POSIX_LOCALE"
printf '| LANGUAGE | %s |\n' "$LANGUAGE_TAG"
printf '| ACCEPT_LANGUAGE | %s |\n\n' "$ACCEPT_LANGUAGE"

if [ "$GEO_PRINT_ONLY" = "1" ]; then
  printf 'printOnly=true; Claude Code was not launched.\n'
  exit 0
fi

export HTTP_PROXY="$HTTP_PROXY_URL"
export HTTPS_PROXY="$HTTP_PROXY_URL"
export ALL_PROXY="$SOCKS_PROXY_URL"
export NO_PROXY="$NO_PROXY_VALUE"
export http_proxy="$HTTP_PROXY_URL"
export https_proxy="$HTTP_PROXY_URL"
export all_proxy="$SOCKS_PROXY_URL"
export no_proxy="$NO_PROXY_VALUE"
export TZ="$EXIT_TIMEZONE"
export LANG="$POSIX_LOCALE"
export LC_ALL="$POSIX_LOCALE"
export LC_MESSAGES="$POSIX_LOCALE"
export LANGUAGE="$LANGUAGE_TAG"
export ACCEPT_LANGUAGE="$ACCEPT_LANGUAGE"

exec "$GEO_CLAUDE_COMMAND" "${CLAUDE_ARGS[@]}"
