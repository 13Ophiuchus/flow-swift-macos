#!/usr/bin/env python3
import argparse
import re
import sys
from pathlib import Path

TARGET = Path("Sources/Network/Websocket/NIO/FlowWebSocketFrameHandler.swift")

INSTRUMENTED_CHANNEL_READ = (
    "\tfunc channelRead(context: ChannelHandlerContext, data: NIOAny) {\n"
    "\t\tlet frame = self.unwrapInboundIn(data)\n\n"
    "\t\tprint(\"[FlowWS RAW] opcode=\\\(frame.opcode) fin=\\\\(frame.fin) length=\\\\(frame.data.readableBytes)\\")\\n\\n"     "\\t\\tswitch frame.opcode {\\n"     "\\t\\tcase .connectionClose:\\n"     "\\t\\t\\tprint(\\"[FlowWS RAW] server sent connectionClose\\")\\n"     "\\t\\t\\tcontext.close(promise: nil)\\n"     "\\t\\t\\treturn\\n"     "\\t\\tcase .ping, .pong:\\n"     "\\t\\t\\tcontext.fireChannelRead(data)\\n"     "\\t\\t\\treturn\\n"     "\\t\\tcase .text, .binary:\\n"     "\\t\\t\\tbreak\\n"     "\\t\\tdefault:\\n"     "\\t\\t\\tcontext.fireChannelRead(data)\\n"     "\\t\\t\\treturn\\n"     "\\t\\t}\\n\\n"     "\\t\\tguard frame.fin else {\\n"     "\\t\\t\\tprint(\\"[FlowWS RAW] fragmented frame received (fin=false)\\")\\n"     "\\t\\t\\tcontext.fireChannelRead(data)\\n"     "\\t\\t\\treturn\\n"     "\\t\\t}\\n\\n"     "\\t\\tvar buffer = frame.unmaskedData\\n"     "\\t\\tguard let bytes = buffer.readBytes(length: buffer.readableBytes) else {\\n"     "\\t\\t\\tcontext.fireChannelRead(data)\\n"     "\\t\\t\\treturn\\n"     "\\t\\t}\\n\\n"     "\\t\\tlet rawString = String(decoding: bytes, as: UTF8.self)\\n"     "\\t\\tprint(\\"[FlowWS RAW] payload=\\\\(rawString.prefix(500))\\")\\n\\n"     "\\t\\tdo {\\n"     "\\t\\t\\tlet envelope = try JSONDecoder().decode(Flow.WebSocketEnvelope.self, from: Data(bytes))\\n"     "\\t\\t\\tonEnvelope?(envelope)\\n"     "\\t\\t\\thandleEnvelope(envelope, context: context)\\n"     "\\t\\t} catch {\\n"     "\\t\\t\\tprint(\\"[FlowWS RAW] DECODE FAILED: \\\\(error)\\")\\n"     "\\t\\t}\\n"     "\\t}\\n" )  ORIGINAL\_PATTERN = re.compile(     r"\\tfunc channelRead\\(context: ChannelHandlerContext, data: NIOAny\\) \{.*?\n\t\}\n",
    re.DOTALL,
)


def apply_instrumentation():
    if not TARGET.exists():
        sys.exit(f"Target not found: {TARGET}")
    text = TARGET.read_text()
    if not ORIGINAL_PATTERN.search(text):
        sys.exit("channelRead pattern not found — inspect manually")
    new_text = ORIGINAL_PATTERN.sub(INSTRUMENTED_CHANNEL_READ, text, count=1)
    TARGET.write_text(new_text)
    print("Applied discovery instrumentation to channelRead")


def analyze_report(log_path: str):
    log = Path(log_path)
    if not log.exists():
        sys.exit(f"Log not found: {log_path}")
    lines = [l for l in log.read_text().splitlines() if "[FlowWS RAW]" in l]

    if not lines:
        print("FINDING: zero raw frames captured.")
        print("RECOMMENDATION: subscribe write or upgrade never completed —")
        print("re-check ALPN pinning and promise resolution timing.")
        return

    decode_failures = [l for l in lines if "DECODE FAILED" in l]
    close_events = [l for l in lines if "connectionClose" in l]
    fragments = [l for l in lines if "fragmented" in l]

    print(f"Captured {len(lines)} raw frame log lines.")
    for l in lines[:20]:
        print("  " + l)

    if decode_failures:
        print(f"FINDING: {len(decode_failures)} decode failures.")
        print("RECOMMENDATION: use a permissive envelope model — decode a minimal")
        print("type-discriminator first, route by shape, only fail hard on truly malformed JSON.")
    if close_events:
        print("FINDING: server issued connectionClose.")
        print("RECOMMENDATION: inspect close code/reason — likely subscribe payload mismatch.")
    if fragments:
        print("FINDING: fragmented frames detected, not reassembled.")
        print("RECOMMENDATION: add frame aggregation (buffer until fin=true).")
    if not (decode_failures or close_events or fragments):
        print("FINDING: frames arrive and decode cleanly under instrumentation.")
        print("RECOMMENDATION: original bug was fail-closed errorCaught — remove")
        print("the unconditional context.close() on decode error.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--report", metavar="LOG_PATH")
    args = parser.parse_args()

    if args.apply:
        apply_instrumentation()
    elif args.report:
        analyze_report(args.report)
    else:
        parser.print_help()
