---
paths:
  - "**/*.png"
  - "**/*.gif"
  - "**/assets/**"
  - "**/sprite/**"
---

# Pixel Art Design Principles — NON-NEGOTIABLE

Follow these principles when creating any pixel art via pxcli.

## Programmatic Workflow (execute in order)
1. **Silhouette first** — block out shape in solid color; must be recognizable filled black
2. **Proportions** — chibi for small sprites (head 1/3–1/2 of height at ≤16x16)
3. **Line work** — 1px outlines; straight lines = uniform step counts; curves = monotonically changing steps
4. **Palette** — 4–8 colors per sprite; hue-shift ramps (cool shadows, warm highlights); ≥15% luminance gap between adjacent shades; no pure colors (#FF0000, #000000)
5. **Shading** — single light source (top-left); shade as 3D forms; NEVER pillow-shade; min 2px width for volume
6. **Outlines** — colored (darker shade of fill) or selective (SelOut); remove at contact points
7. **AA** — only on sprites ≥16x16; internal curves only; length ≈ 30–50% of segment; NEVER AA outer edges
8. **Verify** — silhouette test, orphan pixel check, banding check, jaggies check → export PNG

## Quick Anti-Pattern Checklist
- **Pillow shading**: shade bands parallel outline on all sides → fix: shade from light source
- **Banding**: parallel same-length color bands → fix: vary lengths, stagger
- **Jaggies**: inconsistent step lengths → fix: uniform (straights) / monotonic (curves)
- **Orphan pixels**: isolated single pixels → fix: remove or integrate
- **Straight ramps**: no hue shift → fix: cool shadows, warm highlights
- **Outer-edge AA**: AA on sprite perimeter → fix: keep outer edges crisp
- **1px limbs**: can't show volume → fix: minimum 2px width
- **Mixed pixel density**: assets at different scales → fix: standardize resolution

## Size Guidelines
- **8x8**: symbols only, 2–3 colors, exaggerate one identifying feature
- **16x16**: chibi proportions, colored shapes over outlines, 4–6 colors
- **32x32**: recognizable characters, outlines useful, 6–10 colors

## Color Rules
- Ramps: brightness ↑ = hue shifts warm, saturation ↓; brightness ↓ = hue shifts cool
- Use dark chromatic colors (dark navy, dark brown) instead of pure black
- 60-30-10 color distribution (dominant / secondary / accent)

## Dithering
- Only on large static areas (≥24x24); never on animated sprites
- Irregular patterns > regular checkerboards
- Good for organic textures (stone, bark); bad for smooth surfaces (metal, glass)

## Animation
- Walk: 4–6 frames, run: 6–8, idle: 2–4, attack: 3–5
- Sub-pixel animation: shift colors instead of positions for <1px movement
- Apply squash/stretch (even 1px) and anticipation (1–2 wind-up frames)
