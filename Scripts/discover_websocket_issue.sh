#!/bin/zsh
set -euo pipefail
cd /Users/nicreich/AetherAG-mono/flow-swift-macos
REPORT=/tmp/flow_ws_discovery_report.txt
: > "$REPORT"

echo "== 1. Structural discovery ==" | tee -a "$REPORT"
for f in Sources/Network/Websocket/NIO/FlowWebSocketFrameHandler.swift Sources/Network/Websocket/NIO/FlowNIOWebSocketClient.swift Sources/Network/Websocket/WebsocketModels.swift; do
  echo "--- $f ---" | tee -a "$REPORT"
  wc -l "$f" | tee -a "$REPORT"
done

echo "== 2. Opcode handling coverage ==" | tee -a "$REPORT"
grep -n '\.text\|\.binary\|\.ping\|\.pong\|\.connectionClose\|opcode' Sources/Network/Websocket/NIO/FlowWebSocketFrameHandler.swift | tee -a "$REPORT"

echo "== 3. Error handling / teardown ==" | tee -a "$REPORT"
grep -n 'fireErrorCaught\|errorCaught\|context.close' Sources/Network/Websocket/NIO/FlowWebSocketFrameHandler.swift | tee -a "$REPORT"

echo "== 4. Fragmentation check ==" | tee -a "$REPORT"
grep -n '\.fin\|fragment\|continuation' Sources/Network/Websocket/NIO/FlowWebSocketFrameHandler.swift | tee -a "$REPORT" || echo "No fragmentation handling found" | tee -a "$REPORT"

echo "== 5. Live capture ==" | tee -a "$REPORT"
cp Sources/Network/Websocket/NIO/FlowWebSocketFrameHandler.swift /tmp/FlowWebSocketFrameHandler.swift.bak
python3 Scripts/discover_ws_instrument.py --apply

swift build 2>&1 | tail -20 | tee -a "$REPORT"
timeout 30 swift test --no-parallel --filter WebSocketTests > /tmp/ws_discovery_run.log 2>&1 || true

echo "== 6. Captured raw frame evidence ==" | tee -a "$REPORT"
grep '\\[FlowWS RAW\\]' /tmp/ws_discovery_run.log | tee -a "$REPORT" || echo "No raw frames captured" | tee -a "$REPORT"

echo "== 7. Restoring original file ==" | tee -a "$REPORT"
cp /tmp/FlowWebSocketFrameHandler.swift.bak Sources/Network/Websocket/NIO/FlowWebSocketFrameHandler.swift
swift build 2>&1 | tail -5 | tee -a "$REPORT"

echo "== 8. Analysis ==" | tee -a "$REPORT"
python3 Scripts/discover_ws_instrument.py --report /tmp/ws_discovery_run.log | tee -a "$REPORT"

cat "$REPORT"
