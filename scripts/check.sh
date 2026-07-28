#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
release_file="$repo_dir/capslox-karabiner.json"
check_tmp=$(mktemp "${TMPDIR:-/tmp}/capslox-karabiner-check.XXXXXX")
cleanup() {
  rm -f "$check_tmp"
}
trap cleanup EXIT HUP INT TERM

"$repo_dir/scripts/build.sh" "$check_tmp"

if ! cmp -s "$release_file" "$check_tmp"; then
  echo "capslox-karabiner.edn 与 capslox-karabiner.json 不同步：" >&2
  diff -u "$release_file" "$check_tmp" || true
  exit 1
fi

jq -e . "$release_file" >/dev/null

karabiner_cli_path="/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli"
if [ -x "$karabiner_cli_path" ]; then
  "$karabiner_cli_path" --lint-complex-modifications "$release_file"
elif command -v karabiner_cli >/dev/null 2>&1; then
  karabiner_cli --lint-complex-modifications "$release_file"
else
  echo "提示：未找到 karabiner_cli，已跳过官方规则校验" >&2
fi

echo "EDN、发布 JSON 与规则格式检查通过"
