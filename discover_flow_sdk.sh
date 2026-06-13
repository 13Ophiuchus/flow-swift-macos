#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
OUT="${2:-./flow-discovery}"
SRC_DIRS=("$ROOT/Sources" "$ROOT/Tests")

mkdir -p "$OUT"

find "${SRC_DIRS[@]}" -type f -name '*.swift' \
  -not -path '*/.build/*' \
  -not -path '*/.swiftpm/*' \
  | sort > "$OUT/files.txt"

grep -RInE --include='*.swift' \
  '^[[:space:]]*(public|internal|package|open|private|fileprivate)?[[:space:]]*(final[[:space:]]+)?(class|struct|enum|protocol|actor|extension)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' \
  "${SRC_DIRS[@]}" \
  | sed "s#^$ROOT/##" > "$OUT/types.txt" || true

grep -RInE --include='*.swift' \
  '^[[:space:]]*(public|internal|package|open|private|fileprivate)?[[:space:]]*(static[[:space:]]+|class[[:space:]]+)?func[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' \
  "${SRC_DIRS[@]}" \
  | sed "s#^$ROOT/##" > "$OUT/functions.txt" || true

grep -RInE --include='*.swift' \
  '^[[:space:]]*(public|internal|package|open|private|fileprivate)?[[:space:]]*(static[[:space:]]+)?(let|var)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' \
  "${SRC_DIRS[@]}" \
  | sed "s#^$ROOT/##" > "$OUT/properties.txt" || true

grep -RInE --include='*.swift' \
  '(FlowAccessProtocol|FlowHTTPClient|FlowAccessActor|FlowWebsocketActor|FlowWebSocketCenter|Flow\.Transaction|TransactionBuild|FlowSigner|P256FlowSigner|Flow\.Script|CadenceLoader|Flow\.ID|Flow\.Address|Flow\.Account|getTransactionResultById|sendTransaction|executeScriptAtLatestBlock|subscribeToTransactionStatus)' \
  "$ROOT/Sources" \
  | sed "s#^$ROOT/##" > "$OUT/high-value-flow.txt" || true

awk -F'[:|]' '
  /^FILE\|/ { file=$2; next }
  /^CLASS\|/ || /^STRUCT\|/ || /^ENUM\|/ || /^PROTOCOL\|/ || /^ACTOR\|/ || /^EXTENSION\|/ { print file "|" $0 }
' "$OUT/../flow-sdk-symbols.txt" 2>/dev/null > "$OUT/symbol-file-map.txt" || true

{
  echo "== Files scanned =="
  wc -l < "$OUT/files.txt"

  echo
  echo "== Type counts =="
  grep -hoE "(class|struct|enum|protocol|actor|extension)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*" "$OUT/types.txt" \
    | awk '{print $1}' | sort | uniq -c | sort -nr

  echo
  echo "== Top function files =="
  cut -d: -f1 "$OUT/functions.txt" | sort | uniq -c | sort -nr | head -n 30

  echo
  echo "== High-value Flow files =="
  cut -d: -f1 "$OUT/high-value-flow.txt" | sort | uniq

  echo
  echo "== Transaction-related functions =="
  grep -E 'sendTransaction|getTransactionById|getTransactionResultById|subscribeToTransactionStatus|onceFinalized|onceExecuted|onceSealed|buildTransaction|signPayload|signEnvelope' "$OUT/functions.txt" || true

  echo
  echo "== Script-related functions =="
  grep -E 'executeScriptAtLatestBlock|executeScriptAtBlockId|executeScriptAtBlockHeight|query|decode' "$OUT/functions.txt" || true
} > "$OUT/summary.txt"

echo "Generated reports in: $OUT"
