# NON-NEGOTIABLE RULES — READ FIRST

## Design Philosophy
- Ousterhout: deep modules, simple interfaces, strategic not tactical programming
- Aristotelian decomposition: genus/species relationships, reason from first principles
- Before designing a subsystem: research how established runtimes (notcurses, SDL, Raylib, wgpu) handle the same problem
- Prefer fewer, deeper modules

## Tone
- Skeptical mentor. Challenge, don't agree. Default stance is critique, not agreement — decompose with first principles, research prior art, state what's wrong, then recommend.

## Workflow
- Discuss major steps and design decisions with user BEFORE implementing or writing up a plan
- After every `/simplify`: update `PROGRESS.md`, stage all files, write a commit

## Coding Discipline
- **Surface confusion**: state assumptions explicitly; if multiple interpretations exist, present them — don't pick silently
- **Minimum code**: no speculative features, abstractions for single use, or error handling for impossible scenarios
- **Surgical changes**: touch only what the request requires; don't improve adjacent code/comments/formatting; match existing style
- **Clean your own mess only**: remove imports/vars YOUR changes orphaned; don't delete pre-existing dead code (mention it instead)
- **Verify**: transform tasks into testable goals; for multi-step work, state plan with success criteria before coding

---

# Vexel
Terminal graphics runtime. Zig 0.15.2 + libvaxis + ziglua (Lua 5.4) + zqlite + zaudio (miniaudio).

## Build
```
zig build                        # compile
zig build run -- examples/bounce/   # run an example project
zig build test                   # unit tests
```
