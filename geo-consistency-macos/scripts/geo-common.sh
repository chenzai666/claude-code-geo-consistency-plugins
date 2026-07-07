#!/usr/bin/env bash

set -u

geo_parse_args() {
  GEO_PROXY_HOST="127.0.0.1"
  # Auto-detect listening proxy port: v2rayN(10808) → Clash(7890/7891) → sing-box(7897)
  GEO_HTTP_PORT="10808"
  GEO_SOCKS_PORT="10808"
  for _geo_p in 10808 7890 7891 7897; do
    if nc -z -G 1 "127.0.0.1" "$_geo_p" >/dev/null 2>&1; then
      GEO_HTTP_PORT="$_geo_p"; GEO_SOCKS_PORT="$_geo_p"; break
    fi
  done
  unset _geo_p
  GEO_RC_FILE="${HOME}/.zshrc"
  GEO_JSON="0"
  GEO_SKIP_NETWORK="1"
  GEO_IPINFO_TOKEN="${IPINFO_TOKEN:-}"

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
      --ipinfo-token)
        GEO_IPINFO_TOKEN="$2"; shift 2 ;;
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

geo_profile_value() {
  geo_trace_value "$1"
}

geo_normalize_profile_json() {
  local provider="$1"
  if command -v node >/dev/null 2>&1; then
    node -e 'const provider = process.argv[1]; let text = ""; process.stdin.setEncoding("utf8"); process.stdin.on("data", chunk => { text += chunk; }); process.stdin.on("end", () => { try { const json = JSON.parse(text); let profile; if (provider === "ipinfo") { const [latitude = "", longitude = ""] = String(json.loc || "").split(","); profile = { ok: Boolean(json.ip), provider, ip: json.ip || "", countryCode: String(json.country || "").toUpperCase(), country: "", region: json.region || "", city: json.city || "", latitude, longitude, isp: json.org || "", timezone: json.timezone || "" }; } else if (provider === "ipwhois") { profile = { ok: Boolean(json.success), provider, ip: json.ip || "", countryCode: String(json.country_code || "").toUpperCase(), country: json.country || "", region: json.region || "", city: json.city || "", latitude: json.latitude ?? "", longitude: json.longitude ?? "", isp: json.connection?.isp || json.connection?.org || "", timezone: json.timezone || "" }; } else { profile = { ok: Boolean(json.ip), provider, ip: json.ip || "", countryCode: String(json.country_code || "").toUpperCase(), country: json.country_name || "", region: json.region || "", city: json.city || "", latitude: json.latitude ?? "", longitude: json.longitude ?? "", isp: json.org || "", timezone: json.timezone || "" }; } for (const [key, value] of Object.entries(profile)) { console.log(`${key}=${String(value ?? "").replace(/\r?\n/g, " ")}`); } } catch (error) { console.log("ok=false"); console.log(`provider=${provider}`); console.log(`error=${String(error.message || error).replace(/\r?\n/g, " ")}`); } });' "$provider"
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json, sys
provider = sys.argv[1]
try:
    data = json.load(sys.stdin)
    if provider == "ipinfo":
        loc = str(data.get("loc") or "").split(",", 1)
        profile = {"ok": bool(data.get("ip")), "provider": provider, "ip": data.get("ip", ""), "countryCode": str(data.get("country") or "").upper(), "country": "", "region": data.get("region", ""), "city": data.get("city", ""), "latitude": loc[0] if len(loc) > 0 else "", "longitude": loc[1] if len(loc) > 1 else "", "isp": data.get("org", ""), "timezone": data.get("timezone", "")}
    elif provider == "ipwhois":
        conn = data.get("connection") or {}
        profile = {"ok": bool(data.get("success")), "provider": provider, "ip": data.get("ip", ""), "countryCode": str(data.get("country_code") or "").upper(), "country": data.get("country", ""), "region": data.get("region", ""), "city": data.get("city", ""), "latitude": data.get("latitude", ""), "longitude": data.get("longitude", ""), "isp": conn.get("isp") or conn.get("org") or "", "timezone": data.get("timezone", "")}
    else:
        profile = {"ok": bool(data.get("ip")), "provider": provider, "ip": data.get("ip", ""), "countryCode": str(data.get("country_code") or "").upper(), "country": data.get("country_name", ""), "region": data.get("region", ""), "city": data.get("city", ""), "latitude": data.get("latitude", ""), "longitude": data.get("longitude", ""), "isp": data.get("org", ""), "timezone": data.get("timezone", "")}
    for key, value in profile.items():
        print(f"{key}={str(value).replace(chr(10), chr(32)).replace(chr(13), chr(32))}")
except Exception as error:
    print("ok=false")
    print(f"provider={provider}")
    print(f"error={str(error).replace(chr(10), chr(32)).replace(chr(13), chr(32))}")' "$provider"
    return 0
  fi

  printf 'ok=false\nprovider=%s\nerror=node or python3 is required for JSON parsing\n' "$provider"
}

geo_ip_profile() {
  local proxy="${1:-}"
  local ipinfo_token="${2:-${IPINFO_TOKEN:-}}"
  local errors=""
  local provider url parser out profile ok ip country timezone

  for provider in ipapi ipinfo ipwhois; do
    case "$provider" in
      ipapi)
        url="https://ipapi.co/json/"
        parser="ipapi"
        ;;
      ipinfo)
        if [ -n "$ipinfo_token" ]; then
          url="https://ipinfo.io/json?token=${ipinfo_token}"
        else
          url="https://ipinfo.io/json"
        fi
        parser="ipinfo"
        ;;
      *)
        url="https://ipwho.is/"
        parser="ipwhois"
        ;;
    esac

    local args=(-fsS --connect-timeout 5 --max-time 12)
    if [ -n "$proxy" ]; then
      args+=(--proxy "$proxy")
    fi

    if ! out="$(curl "${args[@]}" "$url" 2>&1)"; then
      errors="${errors}${provider}: ${out}; "
      continue
    fi

    profile="$(printf '%s' "$out" | geo_normalize_profile_json "$parser")"
    ok="$(printf '%s\n' "$profile" | geo_profile_value ok)"
    ip="$(printf '%s\n' "$profile" | geo_profile_value ip)"
    country="$(printf '%s\n' "$profile" | geo_profile_value countryCode)"
    timezone="$(printf '%s\n' "$profile" | geo_profile_value timezone)"
    if [ "$ok" = "true" ] && [ -n "$ip" ] && [ -n "$country" ] && [ -n "$timezone" ]; then
      printf '%s\n' "$profile"
      return 0
    fi
    errors="${errors}${provider}: incomplete profile; "
  done

  printf 'ok=false\nerror=%s\n' "$errors"
}

geo_locale_bundle() {
  local country_code
  local timezone="${2:-}"
  country_code="$(printf '%s' "${1:-}" | tr '[:lower:]' '[:upper:]')"
  local language

  case "$country_code" in
    CN) language="zh-CN" ;;
    HK) language="zh-HK" ;;
    MO) language="zh-MO" ;;
    TW) language="zh-TW" ;;
    US) language="en-US" ;;
    GB) language="en-GB" ;;
    CA) language="en-CA" ;;
    AU) language="en-AU" ;;
    NZ) language="en-NZ" ;;
    SG) language="en-SG" ;;
    JP) language="ja-JP" ;;
    KR) language="ko-KR" ;;
    DE) language="de-DE" ;;
    FR) language="fr-FR" ;;
    IT) language="it-IT" ;;
    ES) language="es-ES" ;;
    NL) language="nl-NL" ;;
    BR) language="pt-BR" ;;
    PT) language="pt-PT" ;;
    RU) language="ru-RU" ;;
    IN) language="en-IN" ;;
    ID) language="id-ID" ;;
    TH) language="th-TH" ;;
    VN) language="vi-VN" ;;
    PH) language="en-PH" ;;
    MY) language="ms-MY" ;;
    *) language="en-US" ;;
  esac

  if [ "$country_code" = "CA" ] && printf '%s' "$timezone" | grep -q '^America/Montreal'; then
    language="fr-CA"
  fi

  local base="${language%%-*}"
  local posix_locale
  posix_locale="$(printf '%s.UTF-8' "$(printf '%s' "$language" | tr '-' '_')")"

  printf 'timezone=%s\n' "$timezone"
  printf 'language=%s\n' "$language"
  printf 'languages=%s,%s\n' "$language" "$base"
  printf 'acceptLanguage=%s,%s;q=0.9\n' "$language" "$base"
  printf 'posixLocale=%s\n' "$posix_locale"
}

geo_node_runtime_profile() {
  if command -v node >/dev/null 2>&1; then
    node <<'NODE'
const profile = {
  nodeTimezone: Intl.DateTimeFormat().resolvedOptions().timeZone || "",
  nodeDateTimeLocale: Intl.DateTimeFormat().resolvedOptions().locale || "",
  nodeNumberLocale: Intl.NumberFormat().resolvedOptions().locale || "",
  nodeCollatorLocale: Intl.Collator().resolvedOptions().locale || "",
  offsetNow: new Date().getTimezoneOffset(),
  offsetJanuary: new Date("2026-01-15T12:00:00Z").getTimezoneOffset(),
  offsetJuly: new Date("2026-07-15T12:00:00Z").getTimezoneOffset()
};
for (const [key, value] of Object.entries(profile)) {
  console.log(`${key}=${String(value ?? "").replace(/\r?\n/g, " ")}`);
}
NODE
    return 0
  fi

  printf 'nodeTimezone=\nnodeDateTimeLocale=\nnodeNumberLocale=\nnodeCollatorLocale=\n'
}

geo_system_timezone() {
  if command -v systemsetup >/dev/null 2>&1; then
    systemsetup -gettimezone 2>/dev/null | awk -F': ' '/Time Zone/ {print $2; exit}'
    return 0
  fi
  if [ -L /etc/localtime ]; then
    readlink /etc/localtime | sed 's#.*zoneinfo/##'
    return 0
  fi
  printf ''
}

geo_runtime_profile() {
  printf 'os=macos\n'
  printf 'envTimezone=%s\n' "${TZ:-}"
  printf 'systemTimezone=%s\n' "$(geo_system_timezone)"
  geo_node_runtime_profile
  printf 'LANG=%s\n' "${LANG:-}"
  printf 'LC_ALL=%s\n' "${LC_ALL:-}"
  printf 'LC_MESSAGES=%s\n' "${LC_MESSAGES:-}"
  printf 'LANGUAGE=%s\n' "${LANGUAGE:-}"
}

geo_locale_matches() {
  local actual expected left right base
  actual="${1:-}"
  expected="${2:-}"
  [ -n "$actual" ] || return 1
  [ -n "$expected" ] || return 1
  left="$(printf '%s' "$actual" | sed -E 's/[.]UTF-8$//I; s/[.]utf8$//I; s/_/-/g' | tr '[:upper:]' '[:lower:]')"
  right="$(printf '%s' "$expected" | sed -E 's/[.]UTF-8$//I; s/[.]utf8$//I; s/_/-/g' | tr '[:upper:]' '[:lower:]')"
  base="${right%%-*}"
  [ "$left" = "$right" ] || printf '%s' "$left" | grep -q "^${base}-"
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
