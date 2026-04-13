---
type: community
cohesion: 0.12
members: 18
---

# Engine Core Architecture

**Cohesion:** 0.12 - loosely connected
**Members:** 18 nodes

## Members
- [[Lua Audio API]] - document - LUA_API.md
- [[Lua Graphics API Phase 0 (textrectclear)]] - document - LUA_API.md
- [[Lua Lifecycle Callbacks (loadupdatedrawquit)]] - document - LUA_API.md
- [[Lua Scene Management API]] - document - LUA_API.md
- [[Main Loop (~60fps)]] - document - ARCHITECTURE.md
- [[Scene Transitions (fadeslidewipe)]] - document - LUA_API.md
- [[audio.zig — miniaudio Wrapper]] - document - ARCHITECTURE.md
- [[input.zig — KeyMouse Event Translation]] - document - ARCHITECTURE.md
- [[lua_api.zig — Engine API Bindings]] - document - ARCHITECTURE.md
- [[lua_engine.zig — Lua State Lifecycle]] - document - ARCHITECTURE.md
- [[main.zig — Standalone Binary Entry Point]] - document - ARCHITECTURE.md
- [[miniaudio Dependency]] - document - DESIGN.md
- [[srcaudioaudio.zig]] - code - PROGRESS.md
- [[srcengineinput.zig]] - code - PROGRESS.md
- [[srcenginescene.zig]] - code - PROGRESS.md
- [[srcmain.zig]] - code - PROGRESS.md
- [[srcscriptinglua_api.zig]] - code - PROGRESS.md
- [[srcscriptinglua_engine.zig]] - code - PROGRESS.md

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/Engine_Core_Architecture
SORT file.name ASC
```

## Connections to other communities
- 2 edges to [[_COMMUNITY_Core Engine Modules]]

## Top bridge nodes
- [[input.zig — KeyMouse Event Translation]] - degree 3, connects to 1 community
- [[miniaudio Dependency]] - degree 2, connects to 1 community