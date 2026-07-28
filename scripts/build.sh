#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
edn_file="$repo_dir/capslox-karabiner.edn"
release_file="$repo_dir/capslox-karabiner.json"
output_file=${1:-$release_file}
goku_bin=${GOKU_BIN:-goku}
jq_bin=${JQ_BIN:-jq}

for required_command in "$goku_bin" "$jq_bin"; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    echo "缺少依赖：$required_command" >&2
    exit 1
  fi
done

build_tmp=$(mktemp -d "${TMPDIR:-/tmp}/capslox-karabiner-build.XXXXXX")
cleanup() {
  rm -rf "$build_tmp"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$build_tmp/config/karabiner"
printf '%s\n' '{"profiles":[{"name":"Default","selected":true,"complex_modifications":{"parameters":{},"rules":[]}}]}' \
  > "$build_tmp/config/karabiner/karabiner.json"

set +e
XDG_CONFIG_HOME="$build_tmp/config" GOKU_EDN_CONFIG_FILE="$edn_file" \
  "$goku_bin" --dry-run \
  > "$build_tmp/profile.json"
goku_status=$?
set -e

# Goku 0.8.0 的 dry-run 成功时也可能返回 1，最终以输出 JSON 是否有效为准。
if [ "$goku_status" -ne 0 ] && [ "$goku_status" -ne 1 ]; then
  echo "Goku 生成失败，退出码：$goku_status" >&2
  exit "$goku_status"
fi

if ! "$jq_bin" -e '.complex_modifications.rules | type == "array"' \
  "$build_tmp/profile.json" >/dev/null; then
  echo "Goku 未生成有效的 complex_modifications 规则" >&2
  sed -n '1,40p' "$build_tmp/profile.json" >&2
  exit 1
fi

"$jq_bin" --slurpfile generated "$build_tmp/profile.json" \
  '.rules = $generated[0].complex_modifications.rules' \
  "$release_file" > "$build_tmp/release.json"

mv "$build_tmp/release.json" "$output_file"
echo "已生成：$output_file"
