---
paths:
  - "**/*.png"
  - "**/*.gif"
  - "**/assets/**"
  - "**/sprite/**"
---

# Asset Creation — NON-NEGOTIABLE

- **Always** use `pxcli` (pixel-art-cli at `../pixel-art-cli/`) for all pixel art and sprite work
- This includes: sprites, tilesets, tile maps, animation frames, character sheets, UI icons, backgrounds — any visual asset
- Available commands: `start`, `stop`, `set_pixel`, `fill_rect`, `line`, `clear`, `get_pixel`, `export`, `undo`, `redo`
- Write one bash script per sprite for efficiency (start daemon, draw, export, stop)
- Export sprites as PNG
