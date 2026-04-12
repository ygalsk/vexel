# Phase 4: Audio

## Goal
Sound effects and music playback via miniaudio.

## Deliverables

### Audio Engine (`src/audio/audio.zig`)
- [ ] miniaudio integration (zig-miniaudio or zaudio)
- [ ] Audio device init/deinit
- [ ] Load audio files — WAV, OGG, MP3
- [ ] PCM playback with multiple channels
- [ ] Music channel — looping background tracks
- [ ] SFX channels — multiple simultaneous one-shot sounds
- [ ] Volume control per channel and master
- [ ] Panning (stereo positioning)
- [ ] Fade in/out

### Lua API
- [ ] `engine.audio.load(path)` → sound handle
- [ ] `sound:play(opts)` — opts: loop, volume, pan
- [ ] `sound:stop()`
- [ ] `sound:pause()` / `sound:resume()`
- [ ] `sound:set_volume(v)`
- [ ] `engine.audio.set_master_volume(v)`
- [ ] `engine.audio.stop_all()`

### Resource Management
- [ ] Sound handle as Lua userdata with GC finalizer
- [ ] Streaming for large music files (don't load entire file into memory)
- [ ] Optional module — games that don't need audio don't link it

## Build System
- [ ] Add miniaudio dependency to `build.zig.zon`
- [ ] Optional audio feature flag in build

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
games/rhythm/assets/         — NEW (test audio files)
```
