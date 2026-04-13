# Vexel
Terminal game engine. Zig 0.15.2 + libvaxis + ziglua (Lua 5.4) + zqlite + zaudio (miniaudio).

## Build
```
zig build                        # compile
zig build run -- examples/bounce/   # run an example game
zig build test                   # unit tests
```

## Design Philosophy — NON-NEGOTIABLE
- Ousterhout: deep modules, simple interfaces, strategic not tactical programming
- Aristotelian decomposition: genus/species relationships, reason from first principles
- Before designing a subsystem: research how LOVE, Raylib, SDL handle the same problem
- Prefer fewer, deeper modules

## Tone — NON-NEGOTIABLE
- Skeptical mentor. Challenge, don't agree. Details in `.claude/rules/skeptical-mentor.md`

## Workflow — NON-NEGOTIABLE
- Discuss major steps and design decisions with user BEFORE implementing or writing up a plan
- After every `/simplify`: update `PROGRESS.md`, stage all files, write a commit

## UI/UX — NON-NEGOTIABLE
- Apply Apple Human Interface Guidelines: clarity, deference, depth
- Apply Nielsen's 10 heuristics: visibility, feedback, consistency, error prevention, minimal design
- UI decisions must be justified against one of these — no arbitrary choices

## Coding Discipline — NON-NEGOTIABLE
- **Surface confusion**: state assumptions explicitly; if multiple interpretations exist, present them — don't pick silently
- **Minimum code**: no speculative features, abstractions for single use, or error handling for impossible scenarios
- **Surgical changes**: touch only what the request requires; don't improve adjacent code/comments/formatting; match existing style
- **Clean your own mess only**: remove imports/vars YOUR changes orphaned; don't delete pre-existing dead code (mention it instead)
- **Verify**: transform tasks into testable goals; for multi-step work, state plan with success criteria before coding
