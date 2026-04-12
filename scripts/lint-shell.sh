#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

require() {
  command -v "$1" > /dev/null 2>&1 || {
    echo "missing command: $1" >&2
    exit 1
  }
}

require shellcheck
require shfmt

files=()
while IFS= read -r file; do
  files+=("$file")
done < <("$SCRIPT_DIR/list-shell-files.sh")

if [ "${#files[@]}" -eq 0 ]; then
  echo "error: no shell files found" >&2
  exit 1
fi

cd "$REPO_ROOT"

shellcheck --severity=warning --external-sources "${files[@]}"
shfmt -d -i 2 -ci -sr -bn "${files[@]}"

echo "shell lint passed"
