#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
OUT_DIR="${2:-./symbol-report}"

mkdir -p "$OUT_DIR"

SWIFT_FILES=$(find "$ROOT/Sources" "$ROOT/Tests" \
  -type f -name '*.swift' \
  -not -path '*/.build/*' \
  -not -path '*/.swiftpm/*')

printf "%s\n" "$SWIFT_FILES" > "$OUT_DIR/files.txt"

grep -RInE \
  --include='*.swift' \
  '^[[:space:]]*(public|internal|package|open|private|fileprivate)?[[:space:]]*(final[[:space:]]+)?(class|struct|enum|protocol|actor|extension)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' \
  "$ROOT/Sources" "$ROOT/Tests" \
  | sed 's#^\./##' \
  > "$OUT_DIR/types.txt" || true

grep -RInE \
  --include='*.swift' \
  '^[[:space:]]*(public|internal|package|open|private|fileprivate)?[[:space:]]*(static[[:space:]]+|class[[:space:]]+)?func[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' \
  "$ROOT/Sources" "$ROOT/Tests" \
  | sed 's#^\./##' \
  > "$OUT_DIR/functions.txt" || true

grep -RInE \
  --include='*.swift' \
  '^[[:space:]]*(public|internal|package|open|private|fileprivate)?[[:space:]]*(static[[:space:]]+)?(let|var)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' \
  "$ROOT/Sources" "$ROOT/Tests" \
  | sed 's#^\./##' \
  > "$OUT_DIR/properties.txt" || true

grep -RInE \
  --include='*.swift' \
  '(Transaction|Account|Address|Block|Cadence|WebSocket|Signer|Signature|ProposalKey|DomainTag|FlowAccess|FlowActor|Publisher)' \
  "$ROOT/Sources" \
  | sed 's#^\./##' \
  > "$OUT_DIR/flow-capabilities.txt" || true

{
  echo "== Type counts by kind =="
  grep -hoE '(class|struct|enum|protocol|actor|extension)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' "$OUT_DIR/types.txt" 2>/dev/null \
    | awk '{print $1}' | sort | uniq -c | sort -nr

  echo
  echo "== Top files by function count =="
  cut -d: -f1 "$OUT_DIR/functions.txt" 2>/dev/null | sort | uniq -c | sort -nr | head -n 40

  echo
  echo "== Flow-focused files =="
  cut -d: -f1 "$OUT_DIR/flow-capabilities.txt" 2>/dev/null | sort | uniq
} > "$OUT_DIR/summary.txt"

echo "Wrote reports to $OUT_DIR"
