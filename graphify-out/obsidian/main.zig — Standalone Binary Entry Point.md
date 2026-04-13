---
source_file: "ARCHITECTURE.md"
type: "document"
community: "Engine Core Architecture"
tags:
  - graphify/document
  - graphify/INFERRED
  - community/Engine_Core_Architecture
---

# main.zig — Standalone Binary Entry Point

## Connections
- [[Main Loop (~60fps)]] - `implements` [INFERRED]
- [[lua_engine.zig — Lua State Lifecycle]] - `references` [INFERRED]
- [[srcmain.zig]] - `implements` [EXTRACTED]

#graphify/document #graphify/INFERRED #community/Engine_Core_Architecture