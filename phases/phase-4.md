# Phase 4: Audio

## Goal
Sound effects and music playback via miniaudio.

## Deliverables

### Audio Engine (`src/audio/audio.zig`)
- [x] miniaudio integration (zaudio from zig-gamedev)
- [x] Audio device init/deinit
- [x] Load audio files — WAV, OGG, MP3
- [x] PCM playback with multiple channels
- [x] Music channel — looping background tracks
- [x] SFX channels — multiple simultaneous one-shot sounds
- [x] Volume control per channel and master
- [x] Panning (stereo positioning)
- [x] Fade in/out

### Lua API
- [x] `engine.audio.load(path)` → sound handle
- [x] `sound:play(opts)` — opts: loop, volume, pan
- [x] `sound:stop()`
- [x] `sound:pause()` / `sound:resume()`
- [x] `sound:set_volume(v)`
- [x] `engine.audio.set_master_volume(v)`
- [x] `engine.audio.stop_all()`

### Resource Management
- [x] Sound handle as Lua userdata with GC finalizer
- [x] Streaming for large music files (don't load entire file into memory)
- [x] Optional module — games that don't need audio don't link it

## Build System
- [x] Add miniaudio dependency to `build.zig.zon`
- [x] Optional audio feature flag in build

## Test Game
Rhythm game or music-synced visuals. Demonstrates:
- Background music playback with looping
- SFX triggered by key presses
- Volume control
- Multiple simultaneous sounds

## Files
```
src/audio/audio.zig          — NEW
build.zig                    — MODIFY (add miniaudio dep)
build.zig.zon                — MODIFY (add miniaudio dep)
src/scripting/lua_api.zig    — MODIFY (audio Lua functions)
games/rhythm/main.lua        — NEW test game
```
