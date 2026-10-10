#!/usr/bin/env bash
# Sync GitHub public SSH keys into authorized_keys, inside a managed block.
# Usage: sync-keys.sh <github-user|url> [more...]
# Env:   AUTHORIZED_KEYS  target file (default: ~/.ssh/authorized_keys)
#        KEYS_URL_BASE    base URL (default: https://github.com), for testing
set -euo pipefail

[ $# -ge 1 ] || { echo "usage: $0 <github-user|url> [more...]" >&2; exit 1; }

AK="${AUTHORIZED_KEYS:-$HOME/.ssh/authorized_keys}"
BASE="${KEYS_URL_BASE:-https://github.com}"
DIR=$(dirname "$AK")
mkdir -p "$DIR"; chmod 700 "$DIR" 2>/dev/null || true
[ -f "$AK" ] || : > "$AK"

TMP=$(mktemp "$DIR/.ak.XXXXXX")
trap 'rm -f "$TMP" "$TMP".*' EXIT
cp "$AK" "$TMP"

for arg in "$@"; do
  case "$arg" in
    http*://*|file://*) url="$arg"; user=$(basename "${arg%.keys}") ;;
    *) user="$arg"; url="$BASE/$arg.keys" ;;
  esac
  case "$user" in *[!A-Za-z0-9_.-]*|"") echo "invalid user: $user" >&2; exit 1 ;; esac

  # fetch first; any failure aborts before touching the real file
  curl -fsSL --max-time 30 "$url" | tr -d '\r' \
    | grep -E '^(ssh-|ecdsa-|sk-)' > "$TMP.new" || true
  if [ ! -s "$TMP.new" ]; then
    echo "no keys fetched from $url; leaving $AK untouched" >&2; exit 1
  fi

  B="# BEGIN github-keys-sync:$user"; E="# END github-keys-sync:$user"
  # content outside this user's block
  awk -v b="$B" -v e="$E" '$0==b{s=1;next} $0==e{s=0;next} !s' "$TMP" > "$TMP.rest"
  # dedupe on "type base64" against fetched set and against manual keys
  awk -v rest="$TMP.rest" 'FILENAME==rest{ if ($0 !~ /^#/ && NF>=2) seen[$1" "$2]=1; next }
       { k=$1" "$2; if (!seen[k]++) print }' "$TMP.rest" "$TMP.new" > "$TMP.keys"

  { cat "$TMP.rest"
    if [ -s "$TMP.keys" ]; then echo "$B"; cat "$TMP.keys"; echo "$E"; fi
  } > "$TMP"
  echo "$user: $(wc -l < "$TMP.keys" | tr -d ' ') key(s) synced"
done

if cmp -s "$TMP" "$AK"; then echo "no changes"; exit 0; fi
cp "$AK" "$AK.bak"
chmod 600 "$TMP"
mv "$TMP" "$AK"
echo "updated $AK (backup: $AK.bak)"
