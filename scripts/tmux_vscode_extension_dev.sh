#!/usr/bin/env bash
# Launch VS Code in extension development mode from the current directory,
# mirroring the repo's "Run ... (isolated)" launch configuration:
#   1. uv sync
#   2. compile every extension under extensions/ (pnpm run compile)
#   3. code --disable-extensions --extensionDevelopmentPath=<each> .
# Unlike the launch config, no debugger is attached — use F5 inside VS Code
# when you need breakpoints.
set -uo pipefail

fail() {
  echo
  echo "$1" >&2
  read -n1 -s -r -p "Press any key to close..."
  exit 1
}

uv sync || fail "uv sync failed."

args=()
for dir in extensions/*/; do
  [ -f "$dir/package.json" ] || continue
  if [ -f pnpm-lock.yaml ]; then
    echo "Compiling ${dir%/}..."
    pnpm --filter "./${dir%/}" run --if-present compile || fail "Compile failed for ${dir%/}."
  fi
  args+=("--extensionDevelopmentPath=$PWD/${dir%/}")
done

[ ${#args[@]} -gt 0 ] || fail "No extensions with a package.json found under extensions/."

code --disable-extensions "${args[@]}" .
