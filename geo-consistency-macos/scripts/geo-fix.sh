#!/usr/bin/env bash

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=geo-common.sh
. "${SCRIPT_DIR}/geo-common.sh"

geo_parse_args "$@" || exit $?

HTTP_PROXY_URL="$(geo_http_proxy)"
SOCKS_PROXY_URL="$(geo_socks_proxy)"
NO_PROXY_VALUE="localhost,127.0.0.1,::1"
BLOCK_START="# >>> claude-code-geo-consistency start <<<"
BLOCK_END="# >>> claude-code-geo-consistency end <<<"

mkdir -p "$(dirname "$GEO_RC_FILE")"
touch "$GEO_RC_FILE"

BLOCK="$(cat <<EOF
${BLOCK_START}
export HTTP_PROXY="${HTTP_PROXY_URL}"
export HTTPS_PROXY="${HTTP_PROXY_URL}"
export ALL_PROXY="${SOCKS_PROXY_URL}"
export http_proxy="${HTTP_PROXY_URL}"
export https_proxy="${HTTP_PROXY_URL}"
export all_proxy="${SOCKS_PROXY_URL}"
export NO_PROXY="${NO_PROXY_VALUE}"
export no_proxy="${NO_PROXY_VALUE}"
${BLOCK_END}
EOF
)"

python3 - "$GEO_RC_FILE" "$BLOCK_START" "$BLOCK_END" "$BLOCK" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
start = sys.argv[2]
end = sys.argv[3]
block = sys.argv[4] + "\n"
text = path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""
pattern = re.compile(re.escape(start) + r".*?" + re.escape(end) + r"\n?", re.S)
if pattern.search(text):
    text = pattern.sub(block, text)
else:
    if text and not text.endswith("\n"):
        text += "\n"
    text += "\n" + block
path.write_text(text, encoding="utf-8")
PY

if command -v git >/dev/null 2>&1; then
  git config --global http.proxy "$HTTP_PROXY_URL" >/dev/null 2>&1 || true
  git config --global https.proxy "$HTTP_PROXY_URL" >/dev/null 2>&1 || true
fi

if command -v npm >/dev/null 2>&1; then
  npm config set proxy "$HTTP_PROXY_URL" >/dev/null 2>&1 || true
  npm config set https-proxy "$HTTP_PROXY_URL" >/dev/null 2>&1 || true
fi

geo_section "Claude Code Geo Fix (macOS)"
geo_kv "rc file" "$GEO_RC_FILE"
geo_kv "HTTP_PROXY" "$HTTP_PROXY_URL"
geo_kv "ALL_PROXY" "$SOCKS_PROXY_URL"
geo_kv "NO_PROXY" "$NO_PROXY_VALUE"

if geo_port_open "$GEO_HTTP_PORT"; then
  geo_kv "proxyPortOpen" "true"
else
  geo_kv "proxyPortOpen" "false"
fi

geo_section "Next Step"
echo "Restart Claude Code from a new terminal, or source the rc file before launching Claude Code:"
echo "source \"$GEO_RC_FILE\""
