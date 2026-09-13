#!/usr/bin/env bash
# run-tests.sh — canonical way to run this package's tests.
# FlowActors.access is a shared singleton configured by multiple @Suite
# structs; per-suite .serialized does not prevent cross-suite races on it.
# Always run with --no-parallel until Option B (per-suite actor instances,
# see Package_serialization_fix_note.md) lands.
set -e
swift test --no-parallel "$@"
