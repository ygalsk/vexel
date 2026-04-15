# Audio

Thin wrapper over zaudio (miniaudio). Intentionally minimal — audio in a terminal engine is a nice-to-have, not a core feature.

## Mental Model

```
Lua: sfx:play({ loop = true, volume = 0.7 })
  -> lua_api VexelSound method dispatch
  -> AudioSystem.play(id, opts)
  -> zaudio.Sound.start()
```

The audio system is a slot allocator around zaudio's sound objects. You load a file, get a `SoundId` (u32), use it to play/stop/fade. zaudio/miniaudio handles mixing, streaming, device output.

## Key File

`src/audio/audio.zig` — 185 LOC. That's it.

## Slot Pattern

Same handle-based free-list pattern as [[graphics#Image Manager|ImageManager]]:

```
slots: ArrayList(SoundSlot)     -- SoundSlot = union { occupied: *zaudio.Sound, free: ?u32 }
first_free: ?u32                -- head of free list
```

Load returns a slot index. Unload destroys the sound and pushes the slot onto the free list. No compaction, no generation counters — simple and sufficient for the expected scale (tens of sounds, not thousands).

## Graceful Degradation

If `zaudio.Engine.create()` fails (no audio device, CI environment, headless server), `available` is set to `false`. All subsequent operations silently no-op. The Lua side never sees an error — `sfx:play()` just does nothing.

This was a deliberate choice: games should run without audio for development/testing. Crashing because there's no sound card is never acceptable.

## Decisions

### Why zaudio over raw miniaudio?
zaudio is the Zig package for miniaudio with proper allocator integration. Using raw miniaudio would mean fighting C memory management. zaudio gives us `init(allocator)` / `deinit()` lifecycle that matches every other subsystem.

### Why no mixer/bus abstraction?
miniaudio already has mixing built in. Adding another layer on top would just be API surface with no functionality. If someone needs audio groups (music bus, sfx bus), that's a Lua-side concern — set volume per category by tracking your own sound IDs.

## Open Questions

- `pause()` and `resume_()` both just call zaudio's stop/start. This means pause doesn't preserve playback position on all backends. Not a real issue yet but worth knowing if someone reports it.
