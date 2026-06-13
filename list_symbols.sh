#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"

if [[ ! -d "$ROOT" ]]; then
  echo "error: root path does not exist: $ROOT" >&2
  exit 1
fi

find "$ROOT" \
  \( -path '*/.build/*' -o -path '*/.git/*' -o -path '*/Packages/*' \) -prune -o \
  -type f -name '*.swift' -print |
while IFS= read -r file; do
  rel="$file"
  [[ "$rel" == ./* ]] && rel="${rel#./}"
  echo "FILE|$rel"

  awk '
    function emit(kind, line,    s, parts, n, i) {
      s = line
      sub(/^[[:space:]]+/, "", s)
      gsub(/[{:<(].*$/, "", s)
      n = split(s, parts, /[[:space:]]+/)

      if (kind == "CLASS") {
        for (i = 1; i <= n; i++) if (parts[i] == "class" && i < n) { print kind "|" parts[i+1]; return }
      }
      if (kind == "STRUCT") {
        for (i = 1; i <= n; i++) if (parts[i] == "struct" && i < n) { print kind "|" parts[i+1]; return }
      }
      if (kind == "ENUM") {
        for (i = 1; i <= n; i++) if (parts[i] == "enum" && i < n) { print kind "|" parts[i+1]; return }
      }
      if (kind == "PROTOCOL") {
        for (i = 1; i <= n; i++) if (parts[i] == "protocol" && i < n) { print kind "|" parts[i+1]; return }
      }
      if (kind == "EXTENSION") {
        for (i = 1; i <= n; i++) if (parts[i] == "extension" && i < n) { print kind "|" parts[i+1]; return }
      }
      if (kind == "FUNC") {
        for (i = 1; i <= n; i++) if (parts[i] == "func" && i < n) { print kind "|" parts[i+1]; return }
      }
      if (kind == "VAR") {
        for (i = 1; i <= n; i++) if ((parts[i] == "var" || parts[i] == "let") && i < n) { print kind "|" parts[i+1]; return }
      }
    }

    {
      line = $0
      sub(/^[[:space:]]+/, "", line)

      if (line ~ /^(public |internal |open |package |fileprivate |private )*(final )*class[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/) {
        emit("CLASS", line)
      }
      else if (line ~ /^(public |internal |open |package |fileprivate |private )*struct[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/) {
        emit("STRUCT", line)
      }
      else if (line ~ /^(public |internal |open |package |fileprivate |private )*enum[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/) {
        emit("ENUM", line)
      }
      else if (line ~ /^(public |internal |open |package |fileprivate |private )*protocol[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/) {
        emit("PROTOCOL", line)
      }
      else if (line ~ /^(public |internal |open |package |fileprivate |private )*extension[[:space:]]+[A-Za-z_][A-Za-z0-9_\\.]*/) {
        emit("EXTENSION", line)
      }
      else if (line ~ /^(public |internal |open |package |fileprivate |private )*(static )*(mutating )*func[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/) {
        emit("FUNC", line)
      }
      else if (line ~ /^(public |internal |open |package |fileprivate |private )*(static )*(let|var)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/) {
        emit("VAR", line)
      }
    }
  ' "$file"

  echo
done
